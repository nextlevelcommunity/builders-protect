import Foundation

public struct WorktreeLocation: Sendable {
    public var worktreeRoot: URL
    public var mainRoot: URL

    public init(worktreeRoot: URL, mainRoot: URL) {
        self.worktreeRoot = worktreeRoot
        self.mainRoot = mainRoot
    }
}

public enum WorktreeSafety {
    private static let heavyDirectories: Set<String> = [
        "node_modules", ".git", ".next", "dist", "build", ".build", "vendor",
        "Pods", "DerivedData", "Library", ".venv", "venv", "__pycache__",
        "target", "coverage", ".turbo", ".cache", ".expo", ".nuxt", ".output",
        "out", "tmp", "temp", "logs", ".idea", ".vscode"
    ]

    public static func mainWorktreeRoot(for folder: URL) -> URL? {
        let gitEntry = folder.appendingPathComponent(".git")
        guard isRegularFile(gitEntry),
              let contents = try? String(contentsOf: gitEntry, encoding: .utf8) else {
            return nil
        }

        let gitdirLine = contents
            .split(whereSeparator: { $0.isNewline })
            .first { $0.lowercased().hasPrefix("gitdir:") }
        guard let gitdirLine else { return nil }

        let raw = gitdirLine
            .dropFirst("gitdir:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let gitdirURL: URL
        if raw.hasPrefix("/") {
            gitdirURL = URL(fileURLWithPath: raw)
        } else {
            gitdirURL = folder.appendingPathComponent(raw).standardizedFileURL
        }

        let gitdir = gitdirURL.path.replacingOccurrences(of: "\\", with: "/")
        guard let marker = gitdir.range(of: "/.git/worktrees/", options: .backwards) else {
            return nil
        }

        let mainPath = String(gitdir[..<marker.lowerBound])
        guard !mainPath.isEmpty else { return nil }
        return URL(fileURLWithPath: mainPath, isDirectory: true).standardizedFileURL
    }

    public static func isLinkedWorktree(_ folder: URL) -> Bool {
        mainWorktreeRoot(for: folder) != nil
    }

    public static func worktreeLocation(
        containing folder: URL,
        maxLevels: Int = 8
    ) -> WorktreeLocation? {
        var current = folder.standardizedFileURL
        for _ in 0...maxLevels {
            if let mainRoot = mainWorktreeRoot(for: current) {
                return WorktreeLocation(worktreeRoot: current, mainRoot: mainRoot)
            }
            if isDirectory(current.appendingPathComponent(".git")) {
                return nil
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return nil
    }

    public static func registeredWorktrees(
        in mainRoot: URL,
        maxCount: Int = 24
    ) -> [URL] {
        let mainRoot = mainRoot.standardizedFileURL
        let worktreesDirectory = mainRoot.appendingPathComponent(".git/worktrees", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: worktreesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var found: [URL] = []
        for entry in entries {
            if found.count >= maxCount { break }
            let gitdirFile = entry.appendingPathComponent("gitdir")
            guard let raw = try? String(contentsOf: gitdirFile, encoding: .utf8) else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }

            let gitdirURL: URL
            if value.hasPrefix("/") {
                gitdirURL = URL(fileURLWithPath: value)
            } else {
                gitdirURL = entry.appendingPathComponent(value).standardizedFileURL
            }
            let worktreeRoot = gitdirURL.deletingLastPathComponent().standardizedFileURL
            guard FileManager.default.fileExists(atPath: worktreeRoot.path),
                  isLinkedWorktree(worktreeRoot),
                  worktreeRoot.path != mainRoot.path else {
                continue
            }
            if !found.contains(where: { $0.path == worktreeRoot.path }) {
                found.append(worktreeRoot)
            }
        }
        return found
    }

    public static func linkedWorktrees(
        under root: URL,
        maxDepth: Int = 4,
        maxCount: Int = 24
    ) -> [URL] {
        let root = root.standardizedFileURL
        var found = registeredWorktrees(in: root, maxCount: maxCount)

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return found
        }

        while let url = enumerator.nextObject() as? URL {
            if found.count >= maxCount { break }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }

            let name = url.lastPathComponent
            let depth = url.pathComponents.count - root.pathComponents.count
            if depth > maxDepth || heavyDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            if name.hasPrefix("."), name != ".worktrees" {
                enumerator.skipDescendants()
                continue
            }
            if isLinkedWorktree(url) {
                if !found.contains(where: { $0.path == url.path }) {
                    found.append(url.standardizedFileURL)
                }
                enumerator.skipDescendants()
            }
        }
        return found
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }

    private static func isDirectory(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeDirectory
    }
}
