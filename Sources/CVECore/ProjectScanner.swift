import Foundation

public struct ScanDiscovery: Sendable {
    public var projects: [ScannedProject]
    public var warnings: [String]

    public init(projects: [ScannedProject], warnings: [String]) {
        self.projects = projects
        self.warnings = warnings
    }
}

public struct ProjectScanner: Sendable {
    public static let lockfileEcosystems: [String: String] = [
        "package-lock.json": "npm",
        "npm-shrinkwrap.json": "npm",
        "pnpm-lock.yaml": "npm",
        "yarn.lock": "npm",
        "bun.lock": "npm",
        "requirements.txt": "pypi",
        "poetry.lock": "pypi",
        "Cargo.lock": "cargo",
        "go.sum": "go",
        "Gemfile.lock": "rubygems",
        "mix.lock": "hex",
        "flake.lock": "nix"
    ]

    public static let projectMarkers: Set<String> = [
        "package.json",
        "pnpm-workspace.yaml",
        "pyproject.toml",
        "requirements.txt",
        "Cargo.toml",
        "go.mod",
        "Gemfile",
        "mix.exs",
        "flake.nix",
        "composer.json",
        "deno.json"
    ]

    private static let heavyDirectories: Set<String> = [
        "node_modules", ".git", ".next", "dist", "build", ".build", "vendor",
        "Pods", "DerivedData", "Library", ".venv", "venv", "__pycache__",
        "target", "coverage", ".turbo", ".cache", ".expo", ".nuxt", ".output",
        "out", "tmp", "temp", "logs", ".idea", ".vscode"
    ]

    private static let maxDepth = 8
    private static let maxLockfileBytes = 1_800_000

    public init() {}

    public func scan(
        folders: [MonitoredFolder],
        excludedPaths: [String] = [],
        projectLimit: Int = 80,
        packageLimit: Int = 700
    ) -> ScanDiscovery {
        var warnings: [String] = []
        var discovered: [String: ScannedProject] = [:]
        var order: [String] = []
        let exclusions = Self.normalizedExclusions(excludedPaths)

        for folder in folders {
            guard discovered.count < projectLimit else { break }
            let resolution = resolve(folder)
            let root = resolution.url
            if Self.isExcluded(root, by: exclusions) {
                continue
            }
            defer {
                if resolution.accessed {
                    root.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                warnings.append("A pasta \(folder.displayName) não existe mais.")
                continue
            }

            if isProjectRoot(root),
               let scanned = buildProject(at: root, warnings: &warnings, packageLimit: packageLimit),
               !scanned.payloads.isEmpty,
               discovered.count < projectLimit {
                let path = root.standardizedFileURL.path
                discovered[path] = scanned
                order.append(path)
            }

            let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants],
                errorHandler: { url, error in
                    warnings.append("Não consegui ler \(url.lastPathComponent): \(error.localizedDescription)")
                    return true
                }
            ) else {
                warnings.append("Não consegui abrir a pasta \(folder.displayName).")
                continue
            }

            while let url = enumerator.nextObject() as? URL {
                if discovered.count >= projectLimit {
                    warnings.append("Limite de \(projectLimit) projetos por varredura atingido.")
                    break
                }
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isDirectory == true else { continue }

                if Self.isExcluded(url, by: exclusions) {
                    enumerator.skipDescendants()
                    continue
                }

                let name = url.lastPathComponent
                let depth = url.pathComponents.count - root.pathComponents.count
                if depth > Self.maxDepth || Self.heavyDirectories.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }
                if name.hasPrefix("."), name != ".worktrees" {
                    enumerator.skipDescendants()
                    continue
                }

                guard isProjectRoot(url) else { continue }
                let path = url.standardizedFileURL.path
                guard discovered[path] == nil else { continue }

                let scanned = buildProject(at: url, warnings: &warnings, packageLimit: packageLimit)
                guard let scanned, !scanned.payloads.isEmpty else { continue }
                discovered[path] = scanned
                order.append(path)
            }
        }

        let projects = order.compactMap { discovered[$0] }
        if projects.isEmpty && !folders.isEmpty {
            warnings.append("Nenhum projeto com lockfile foi encontrado nas pastas monitoradas.")
        }

        return ScanDiscovery(projects: projects, warnings: warnings)
    }

    public func preview(
        folders: [MonitoredFolder],
        excludedPaths: [String] = []
    ) -> ScanDiscovery {
        scan(
            folders: folders,
            excludedPaths: excludedPaths,
            projectLimit: 40,
            packageLimit: 80
        )
    }

    private static func normalizedExclusions(_ paths: [String]) -> [String] {
        paths.map { path in
            var normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            if normalized.count > 1, normalized.hasSuffix("/") {
                normalized.removeLast()
            }
            return normalized
        }
    }

    private static func isExcluded(_ url: URL, by exclusions: [String]) -> Bool {
        guard !exclusions.isEmpty else { return false }
        let path = url.standardizedFileURL.path
        return exclusions.contains { excluded in
            path == excluded || path.hasPrefix(excluded + "/")
        }
    }

    private func resolve(_ folder: MonitoredFolder) -> (url: URL, accessed: Bool) {
        if let data = folder.bookmarkData {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return (url, url.startAccessingSecurityScopedResource())
            }
        }
        let url = folder.url
        return (url, url.startAccessingSecurityScopedResource())
    }

    private func isProjectRoot(_ url: URL) -> Bool {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        let names = Set(files)
        if !names.isDisjoint(with: Self.projectMarkers) { return true }
        return !names.isDisjoint(with: Self.lockfileEcosystems.keys)
    }

    private func buildProject(
        at url: URL,
        warnings: inout [String],
        packageLimit: Int
    ) -> ScannedProject? {
        let files = Set((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [])
        let packageJSON = parsePackageJSON(at: url, files: files)
        let displayName = packageJSON.name?.isEmpty == false
            ? packageJSON.name!
            : url.lastPathComponent

        var payloads: [LockfilePayload] = []
        var usedEcosystems: Set<String> = []
        let directNames = Set(packageJSON.directNames)

        let npmLockfiles = ["package-lock.json", "npm-shrinkwrap.json"]
        for name in npmLockfiles where files.contains(name) {
            if let payload = parseNPMLockfile(
                at: url.appendingPathComponent(name),
                name: name,
                directNames: directNames,
                packageLimit: packageLimit,
                warnings: &warnings
            ) {
                payloads.append(payload)
                usedEcosystems.insert("npm")
            }
        }

        let rawLockfiles = [
            "pnpm-lock.yaml", "yarn.lock", "bun.lock",
            "requirements.txt", "poetry.lock", "Cargo.lock", "go.sum",
            "Gemfile.lock", "mix.lock", "flake.lock"
        ]
        for name in rawLockfiles where files.contains(name) {
            if let payload = rawLockfile(
                at: url.appendingPathComponent(name),
                name: name,
                warnings: &warnings
            ) {
                payloads.append(payload)
                if let ecosystem = Self.lockfileEcosystems[name] {
                    usedEcosystems.insert(ecosystem)
                }
            }
        }

        if payloads.isEmpty && !packageJSON.pinnedPackages.isEmpty {
            payloads.append(
                LockfilePayload(
                    name: "package.json",
                    packages: packageJSON.pinnedPackages,
                    note: "Versões exatas declaradas no package.json."
                )
            )
            usedEcosystems.insert("npm")
        }

        guard !payloads.isEmpty else { return nil }

        let lockfileNames = payloads.map(\.name)
        let ref = ProjectRef(
            path: url.standardizedFileURL.path,
            name: displayName,
            lockfiles: lockfileNames,
            ecosystems: Array(usedEcosystems).sorted()
        )
        return ScannedProject(ref: ref, payloads: payloads)
    }

    private func parsePackageJSON(
        at url: URL,
        files: Set<String>
    ) -> (name: String?, directNames: [String], pinnedPackages: [PackageCoordinate]) {
        guard files.contains("package.json") else { return (nil, [], []) }
        let file = url.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: file),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, [], [])
        }

        let name = root["name"] as? String
        let sections = [
            "dependencies", "devDependencies", "optionalDependencies", "peerDependencies"
        ]
        var declared: [String: String] = [:]
        for section in sections {
            guard let values = root[section] as? [String: Any] else { continue }
            for (key, value) in values {
                if let version = value as? String {
                    declared[key] = version
                }
            }
        }

        let directNames = declared.keys.sorted()
        var pinned: [PackageCoordinate] = []
        for (key, value) in declared.sorted(by: { $0.key < $1.key }) {
            guard Semver.isExact(value) else { continue }
            pinned.append(
                PackageCoordinate(
                    ecosystem: "npm",
                    name: key,
                    version: Semver.normalized(value)
                )
            )
        }
        return (name, directNames, pinned)
    }

    private func parseNPMLockfile(
        at url: URL,
        name: String,
        directNames: Set<String>,
        packageLimit: Int,
        warnings: inout [String]
    ) -> LockfilePayload? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            warnings.append("Não consegui ler \(name) em \(url.deletingLastPathComponent().lastPathComponent).")
            return nil
        }

        var packages: [String: PackageCoordinate] = [:]

        if let entries = root["packages"] as? [String: Any] {
            for (key, rawValue) in entries {
                guard !key.isEmpty,
                      let value = rawValue as? [String: Any],
                      value["link"] as? Bool != true,
                      let version = value["version"] as? String,
                      !version.isEmpty else {
                    continue
                }
                guard let packageName = key.components(separatedBy: "node_modules/").last,
                      !packageName.isEmpty else { continue }
                let coordinate = PackageCoordinate(
                    ecosystem: "npm",
                    name: packageName,
                    version: Semver.normalized(version)
                )
                packages["\(packageName)@\(coordinate.version)"] = coordinate
            }
        }

        if packages.isEmpty, let dependencies = root["dependencies"] as? [String: Any] {
            collectV1Dependencies(dependencies, into: &packages)
        }

        guard !packages.isEmpty else {
            warnings.append("O \(name) de \(url.deletingLastPathComponent().lastPathComponent) não tinha pacotes legíveis.")
            return nil
        }

        let sorted = packages.values.sorted { lhs, rhs in
            let lhsDirect = directNames.contains(lhs.name)
            let rhsDirect = directNames.contains(rhs.name)
            if lhsDirect != rhsDirect { return lhsDirect }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return Semver.lessThan(lhs.version, rhs.version)
        }

        return LockfilePayload(
            name: name,
            packages: Array(sorted.prefix(packageLimit)),
            note: sorted.count > packageLimit
                ? "\(sorted.count - packageLimit) pacotes adicionais não enviados nesta varredura."
                : nil
        )
    }

    private func collectV1Dependencies(
        _ dependencies: [String: Any],
        into packages: inout [String: PackageCoordinate]
    ) {
        for (name, rawValue) in dependencies {
            guard let value = rawValue as? [String: Any],
                  let version = value["version"] as? String else { continue }
            let normalized = Semver.normalized(version)
            packages["\(name)@\(normalized)"] = PackageCoordinate(
                ecosystem: "npm",
                name: name,
                version: normalized
            )
            if let children = value["dependencies"] as? [String: Any] {
                collectV1Dependencies(children, into: &packages)
            }
        }
    }

    private func rawLockfile(
        at url: URL,
        name: String,
        warnings: inout [String]
    ) -> LockfilePayload? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue <= Self.maxLockfileBytes else {
            warnings.append("O \(name) em \(url.deletingLastPathComponent().lastPathComponent) é grande demais para esta varredura.")
            return nil
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8),
              !content.isEmpty else {
            warnings.append("Não consegui ler \(name) em \(url.deletingLastPathComponent().lastPathComponent).")
            return nil
        }
        return LockfilePayload(name: name, content: content)
    }
}
