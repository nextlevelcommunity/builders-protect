import Foundation

enum LaunchAtLogin {
    static let label = "com.culturabuilder.buildersprotect"
    private static let legacyLabel = "com.culturabuilder.cvebuilders"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    private static var legacyPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(legacyLabel).plist")
    }

    static var isEnabled: Bool {
        isEnabled(at: plistURL)
    }

    private static func isEnabled(at url: URL) -> Bool {
        guard let existing = NSDictionary(contentsOf: url) as? [String: Any],
              let arguments = existing["ProgramArguments"] as? [String],
              let path = arguments.dropFirst(2).first else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }

    static func migrateLegacy(bundleURL: URL = Bundle.main.bundleURL) {
        guard FileManager.default.fileExists(atPath: legacyPlistURL.path) else { return }
        let wasEnabled = isEnabled(at: legacyPlistURL)
        runLaunchctl(["bootout", "gui/\(getuid())/\(legacyLabel)"])
        try? FileManager.default.removeItem(at: legacyPlistURL)
        if wasEnabled, bundleURL.pathExtension == "app" {
            _ = install(appPath: bundleURL.path)
        }
    }

    @discardableResult
    static func setEnabled(
        _ enabled: Bool,
        bundleURL: URL = Bundle.main.bundleURL
    ) -> Bool {
        if enabled {
            guard bundleURL.pathExtension == "app" else { return false }
            return install(appPath: bundleURL.path)
        }
        disable()
        return true
    }

    static func ensure(bundleURL: URL) {
        migrateLegacy(bundleURL: bundleURL)
        guard bundleURL.pathExtension == "app" else { return }
        guard !isEnabled else { return }
        install(appPath: bundleURL.path)
    }

    static func refreshIfEnabled(bundleURL: URL = Bundle.main.bundleURL) {
        guard bundleURL.pathExtension == "app", isEnabled else { return }
        guard let existing = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let arguments = existing["ProgramArguments"] as? [String],
              !arguments.contains("--background") else {
            return
        }
        try? writePlist(appPath: bundleURL.path)
    }

    static func disable() {
        try? FileManager.default.removeItem(at: plistURL)
        try? FileManager.default.removeItem(at: legacyPlistURL)
        runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
        runLaunchctl(["bootout", "gui/\(getuid())/\(legacyLabel)"])
    }

    @discardableResult
    private static func install(appPath: String) -> Bool {
        do {
            try writePlist(appPath: appPath)
            runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
            runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
            return isEnabled
        } catch {
            return false
        }
    }

    private static func writePlist(appPath: String) throws {
        let contents: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-gj", appPath, "--args", "--background"],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua"
        ]

        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: contents,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: plistURL.path
        )
    }

    private static func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
