import Foundation

public enum FolderExclusionPlanner {
    public static func normalized(_ paths: [String]) -> [String] {
        let unique = Array(Set(paths.map(clean))).sorted()
        return unique.filter { path in
            !unique.contains { other in
                other != path && path.hasPrefix(other + "/")
            }
        }
    }

    public static func ignoring(_ paths: [String], exclusions: [String]) -> [String] {
        normalized(exclusions + roots(of: paths))
    }

    public static func reactivating(
        _ paths: Set<String>,
        exclusions: [String],
        candidates: [String]
    ) -> [String] {
        var updated = normalized(exclusions)
        let selected = Set(paths.map(clean))
        for path in selected.sorted(by: { $0.count < $1.count }) {
            if updated.contains(path) {
                updated.removeAll { $0 == path }
                continue
            }
            guard let ancestor = nearestExclusion(for: path, in: updated),
                  ancestor != path else {
                continue
            }

            updated.removeAll { $0 == ancestor }
            for other in candidates.map(clean) where other != path
                && other.hasPrefix(ancestor + "/")
                && !path.hasPrefix(other + "/")
                && !selected.contains(other)
                && nearestExclusion(for: other, in: updated) == nil {
                updated.append(other)
            }
        }
        return normalized(updated)
    }

    public static func nearestExclusion(for path: String, in exclusions: [String]) -> String? {
        let path = clean(path)
        return exclusions
            .map(clean)
            .filter { path == $0 || path.hasPrefix($0 + "/") }
            .max { $0.count < $1.count }
    }

    private static func roots(of paths: [String]) -> [String] {
        let unique = Array(Set(paths.map(clean)))
        return unique.filter { path in
            !unique.contains { other in
                other != path && path.hasPrefix(other + "/")
            }
        }
    }

    private static func clean(_ path: String) -> String {
        var value = path.replacingOccurrences(of: "\\", with: "/")
        while value.count > 1, value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
