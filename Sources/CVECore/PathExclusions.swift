import Foundation

public enum PathExclusions {
    public static func normalized(_ paths: [String]) -> [String] {
        let unique = Array(Set(paths.map(clean))).sorted()
        return unique.filter { path in
            !unique.contains { other in
                other != path && path.hasPrefix(other + "/")
            }
        }
    }

    public static func contains(_ path: String, in exclusions: [String]) -> Bool {
        let candidate = clean(path)
        return exclusions.contains { excluded in
            candidate == excluded || candidate.hasPrefix(excluded + "/")
        }
    }

    public static func contains(_ url: URL, in exclusions: [String]) -> Bool {
        contains(url.standardizedFileURL.path, in: exclusions)
    }

    public static func contains(
        relativePath: String,
        projectPath: String,
        in exclusions: [String]
    ) -> Bool {
        let url = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent(relativePath)
        return contains(url, in: exclusions)
    }

    private static func clean(_ path: String) -> String {
        var value = URL(fileURLWithPath: path).standardizedFileURL.path
        while value.count > 1, value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
