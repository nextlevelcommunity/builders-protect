import Foundation

public enum ProjectPathHeuristics {
    private static let artifactDirectories: Set<String> = [
        "artifacts", "artifact", "releases", "release", "preview", "previews",
        "snapshots", "snapshot", "backup", "backups", "dist", "build", "out",
        "output", "outputs", "tmp", "temp", "cache", "caches", "generated",
        ".worktrees", "node_modules", "vendor", "pods", "deriveddata"
    ]

    public static func isLikelyArtifact(path: String) -> Bool {
        artifactComponent(in: path) != nil
    }

    public static func artifactComponent(in path: String) -> String? {
        let components = path
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.lowercased() }

        return components.first { artifactDirectories.contains($0) }
    }
}
