import Foundation

public struct PestFileRef: Sendable, Hashable {
    public var path: String
    public var bytes: Int
    public var priority: Int

    public init(path: String, bytes: Int, priority: Int) {
        self.path = path
        self.bytes = bytes
        self.priority = priority
    }
}

public struct PestInventory: Sendable {
    public var files: [PestFileRef]
    public var warnings: [String]
    public var skippedFiles: Int
    public var totalBytes: Int
    public var candidateFiles: Int

    public init(
        files: [PestFileRef],
        warnings: [String],
        skippedFiles: Int,
        totalBytes: Int,
        candidateFiles: Int
    ) {
        self.files = files
        self.warnings = warnings
        self.skippedFiles = skippedFiles
        self.totalBytes = totalBytes
        self.candidateFiles = candidateFiles
    }
}

public struct PestSourceFile: Sendable {
    public var path: String
    public var content: String
    public var bytes: Int
    public var truncated: Bool
    public var redactions: Int
    public var firstRedactionLine: Int?

    public init(
        path: String,
        content: String,
        bytes: Int,
        truncated: Bool,
        redactions: Int,
        firstRedactionLine: Int?
    ) {
        self.path = path
        self.content = content
        self.bytes = bytes
        self.truncated = truncated
        self.redactions = redactions
        self.firstRedactionLine = firstRedactionLine
    }
}

public struct PestCollector: Sendable {
    public var maxFiles: Int
    public var maxFileBytes: Int
    public var maxTotalBytes: Int
    public var maxDepth: Int

    public init(
        maxFiles: Int = 64,
        maxFileBytes: Int = 48_000,
        maxTotalBytes: Int = 1_200_000,
        maxDepth: Int = 12
    ) {
        self.maxFiles = maxFiles
        self.maxFileBytes = maxFileBytes
        self.maxTotalBytes = maxTotalBytes
        self.maxDepth = maxDepth
    }

    private static let heavyDirectories: Set<String> = [
        "node_modules", ".git", ".next", "dist", "build", ".build", "vendor",
        "Pods", "DerivedData", "Library", ".venv", "venv", "__pycache__",
        "target", "coverage", ".turbo", ".cache", ".expo", ".nuxt", ".output",
        "out", "tmp", "temp", "logs", ".idea", ".vscode", ".husky", ".yarn"
    ]

    private static let allowedExtensions: Set<String> = [
        "swift", "m", "mm", "h", "c", "cc", "cpp", "cxx", "hpp",
        "js", "jsx", "ts", "tsx", "mjs", "cjs", "vue", "svelte",
        "py", "rb", "go", "rs", "java", "kt", "kts", "php", "cs",
        "sh", "bash", "zsh", "fish", "ps1", "sql", "graphql", "gql",
        "yml", "yaml", "toml", "json", "xml", "plist", "tf", "hcl",
        "dockerfile", "conf", "config", "ini", "env.example", "properties",
        "gradle", "md"
    ]

    private static let allowedNames: Set<String> = [
        "Dockerfile", "Makefile", "Procfile", "Gemfile", "Rakefile",
        "Vagrantfile", "package.json", "pyproject.toml", "Cargo.toml",
        "go.mod", "composer.json", "deno.json", "tsconfig.json",
        "nginx.conf", "httpd.conf", "sshd_config", "mongod.conf"
    ]

    private static let lockfiles: Set<String> = [
        "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml",
        "yarn.lock", "bun.lock", "Cargo.lock", "poetry.lock",
        "Gemfile.lock", "go.sum", "mix.lock", "flake.lock"
    ]

    private static let sensitiveNames: Set<String> = [
        ".npmrc", ".yarnrc", ".pypirc", ".netrc", ".git-credentials",
        "id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"
    ]

    private static let securityHints: [String] = [
        "auth", "login", "session", "jwt", "oauth", "admin", "permission",
        "acl", "role", "security", "crypto", "secret", "token", "password",
        "api", "route", "router", "controller", "handler", "middleware",
        "webhook", "payment", "checkout", "billing", "order", "wallet",
        "upload", "download", "file", "storage", "media", "export", "import",
        "sql", "query", "database", "repository", "dao", "model", "migration",
        "exec", "shell", "command", "process", "worker", "job", "cron",
        "proxy", "fetch", "http", "client", "integration", "callback",
        "redirect", "cors", "csrf", "header", "cookie", "config", "settings",
        "server", "app", "main", "index", "docker", "compose", "nginx", "sshd"
    ]

    public func inventory(
        projectPath: String,
        excludedPaths: [String] = []
    ) throws -> PestInventory {
        let root = URL(fileURLWithPath: projectPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PestError.projectNotFound
        }

        let exclusions = PathExclusions.normalized(excludedPaths)
        if PathExclusions.contains(root, in: exclusions) {
            throw PestError.projectExcluded
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ]
        var selected: [PestFileRef] = []
        var warnings: [String] = []
        var skipped = 0
        var candidates = 0

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                warnings.append("Não consegui ler \(url.lastPathComponent): \(error.localizedDescription)")
                return true
            }
        ) else {
            throw PestError.noFiles
        }

        while let url = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            let depth = url.pathComponents.count - root.pathComponents.count
            let name = url.lastPathComponent

            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            if PathExclusions.contains(url, in: exclusions) {
                enumerator.skipDescendants()
                continue
            }
            if Self.heavyDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            guard values?.isRegularFile == true,
                  values?.isSymbolicLink != true else { continue }

            if Self.lockfiles.contains(name) || isSensitive(name) {
                skipped += 1
                continue
            }

            let ext = url.pathExtension.lowercased()
            let isAllowedName = Self.allowedNames.contains(name)
            guard isAllowedName || Self.allowedExtensions.contains(ext) else { continue }
            if name.hasSuffix(".min.js") || name.hasSuffix(".min.css") || name.hasSuffix(".map") {
                skipped += 1
                continue
            }

            let size = values?.fileSize ?? 0
            guard size > 0 else { continue }
            if size > maxFileBytes * 4 {
                skipped += 1
                continue
            }

            let relative = relativePath(of: url, root: root)
            let ref = PestFileRef(
                path: relative,
                bytes: min(size, maxFileBytes),
                priority: priority(for: relative, size: size)
            )
            candidates += 1
            insert(ref, into: &selected)
        }

        var files: [PestFileRef] = []
        var totalBytes = 0
        for ref in selected {
            if !files.isEmpty, totalBytes + ref.bytes > maxTotalBytes {
                skipped += 1
                continue
            }
            files.append(ref)
            totalBytes += ref.bytes
        }

        if candidates > files.count {
            warnings.append(
                "O Pest selecionou os \(files.count) arquivos mais sensíveis entre \(candidates) candidatos para manter a memória baixa."
            )
        }
        if skipped > 0 {
            warnings.append("\(skipped) arquivo(s) binário(s), sensível(is) ou fora do limite ficaram de fora.")
        }
        if files.count >= maxFiles {
            warnings.append("O limite de \(maxFiles) arquivos por execução foi atingido; o Pest priorizou os caminhos mais sensíveis.")
        }

        return PestInventory(
            files: files,
            warnings: warnings,
            skippedFiles: skipped,
            totalBytes: totalBytes,
            candidateFiles: candidates
        )
    }

    public func chunks(of files: [PestFileRef], maxCharacters: Int) -> [[PestFileRef]] {
        var chunks: [[PestFileRef]] = []
        var current: [PestFileRef] = []
        var currentCharacters = 0

        for file in files {
            let cost = min(file.bytes, maxFileBytes) + file.path.count + 140
            if !current.isEmpty, currentCharacters + cost > maxCharacters {
                chunks.append(current)
                current = []
                currentCharacters = 0
            }
            current.append(file)
            currentCharacters += cost
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    public func relativePath(of url: URL, root: URL) -> String {
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let filePath = url.standardizedFileURL.resolvingSymlinksInPath().path
        if filePath.hasPrefix(rootPrefix) {
            return String(filePath.dropFirst(rootPrefix.count))
        }
        return url.lastPathComponent
    }

    private func insert(_ ref: PestFileRef, into selected: inout [PestFileRef]) {
        if selected.count < maxFiles {
            selected.append(ref)
            selected.sort(by: Self.precedes)
            return
        }
        guard let last = selected.last, Self.precedes(ref, last) else { return }
        selected[selected.count - 1] = ref
        selected.sort(by: Self.precedes)
    }

    private static func precedes(_ lhs: PestFileRef, _ rhs: PestFileRef) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.bytes != rhs.bytes { return lhs.bytes < rhs.bytes }
        return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
    }

    private func priority(for path: String, size: Int) -> Int {
        let lower = path.lowercased()
        var score = 0
        for hint in Self.securityHints where lower.contains(hint) {
            score += 4
        }
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "js", "jsx", "ts", "tsx", "py", "rb", "go", "rs", "java", "kt", "php", "cs":
            score += 12
        case "sql", "graphql", "gql":
            score += 10
        case "yml", "yaml", "toml", "conf", "config", "ini", "properties", "plist":
            score += 7
        case "json", "xml", "tf", "hcl":
            score += 4
        case "md":
            score -= 16
        default:
            break
        }
        if lower.contains("/test/") || lower.contains("/tests/") || lower.contains("/spec/")
            || lower.contains("/__tests__/") || lower.contains("/fixtures/")
            || lower.contains("/mocks/") || lower.contains(".test.") || lower.contains(".spec.") {
            score -= 24
        }
        let depth = path.split(separator: "/").count
        if depth <= 3 { score += 5 }
        if size > maxFileBytes { score -= 2 }
        return score
    }

    private func isSensitive(_ name: String) -> Bool {
        let lower = name.lowercased()
        if Self.sensitiveNames.contains(lower) { return true }
        if lower.hasPrefix(".env") { return true }
        if lower.contains("secret") || lower.contains("credential") { return true }
        if lower.hasSuffix(".pem") || lower.hasSuffix(".key") || lower.hasSuffix(".p12")
            || lower.hasSuffix(".pfx") || lower.hasSuffix(".crt") || lower.hasSuffix(".cer") {
            return true
        }
        return false
    }
}

public struct PestReader: Sendable {
    public init() {}

    public func read(
        _ ref: PestFileRef,
        projectPath: String,
        maxBytes: Int
    ) throws -> PestSourceFile? {
        let root = URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL
        let url = root.appendingPathComponent(ref.path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
        guard !data.isEmpty, !data.contains(0) else { return nil }
        let truncated = data.count > maxBytes
        let payload = truncated ? data.prefix(maxBytes) : data
        guard let text = String(data: payload, encoding: .utf8) else { return nil }

        let redaction = Self.redact(text)
        return PestSourceFile(
            path: ref.path,
            content: redaction.text,
            bytes: data.count,
            truncated: truncated,
            redactions: redaction.count,
            firstRedactionLine: redaction.firstLine
        )
    }

    public static func maskEvidence(_ text: String, limit: Int = 220) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let masked = redact(trimmed).text
        if masked.count <= limit { return masked }
        return String(masked.prefix(limit)) + "…"
    }

    public static func redact(_ text: String) -> (text: String, count: Int, firstLine: Int?) {
        var value = text
        let rules: [(String, String)] = [
            (
                #"(?is)-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"#,
                "[REDACTED]"
            ),
            (
                #"(?i)(api[_-]?key|secret|token|password|passwd|client[_-]?secret|private[_-]?key|access[_-]?key)\s*[:=]\s*["']?[^"'\s,}]+"#,
                "$1 = \"[REDACTED]\""
            ),
            (#"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b"#, "[REDACTED]"),
            (#"\bsk-[A-Za-z0-9]{20,}\b"#, "[REDACTED]"),
            (#"\bAKIA[0-9A-Z]{16}\b"#, "[REDACTED]")
        ]
        for (pattern, replacement) in rules {
            value = value.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        let count = value.components(separatedBy: "[REDACTED]").count - 1
        let firstLine = count > 0
            ? value.split(separator: "\n", omittingEmptySubsequences: false)
                .firstIndex(where: { $0.contains("[REDACTED]") })
                .map { $0 + 1 }
            : nil
        return (value, count, firstLine)
    }
}
