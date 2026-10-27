import Foundation

public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let fileManager: FileManager
    private let supportDirectory: URL
    private let settingsURL: URL
    private let reportURL: URL
    private let redTeamURL: URL
    private let pestURL: URL
    private let networkURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        let base = supportRoot.appendingPathComponent("Builders Protect", isDirectory: true)
        let legacy = supportRoot.appendingPathComponent("CVE Builders", isDirectory: true)

        if !fileManager.fileExists(atPath: base.path),
           fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
            for name in ["settings.json", "report.json", "redteam.json", "pest.json", "network.json"] {
                let source = legacy.appendingPathComponent(name)
                let target = base.appendingPathComponent(name)
                if fileManager.fileExists(atPath: source.path) {
                    try? fileManager.copyItem(at: source, to: target)
                }
            }
        }

        self.supportDirectory = base
        self.settingsURL = base.appendingPathComponent("settings.json")
        self.reportURL = base.appendingPathComponent("report.json")
        self.redTeamURL = base.appendingPathComponent("redteam.json")
        self.pestURL = base.appendingPathComponent("pest.json")
        self.networkURL = base.appendingPathComponent("network.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public var directory: URL { supportDirectory }

    public func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func saveSettings(_ settings: AppSettings) {
        ensureDirectory()
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: settingsURL.path
        )
    }

    public func loadReport() -> ScanReport? {
        guard let data = try? Data(contentsOf: reportURL) else { return nil }
        return try? decoder.decode(ScanReport.self, from: data)
    }

    public func saveReport(_ report: ScanReport?) {
        ensureDirectory()
        guard let report else {
            try? fileManager.removeItem(at: reportURL)
            return
        }
        guard let data = try? encoder.encode(report) else { return }
        try? data.write(to: reportURL, options: .atomic)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: reportURL.path
        )
    }

    public func loadRedTeamReports() -> [String: RedTeamReport] {
        guard let data = try? Data(contentsOf: redTeamURL),
              let reports = try? decoder.decode([String: RedTeamReport].self, from: data) else {
            return [:]
        }
        return reports
    }

    public func saveRedTeamReport(_ report: RedTeamReport) {
        ensureDirectory()
        var reports = loadRedTeamReports()
        reports[report.projectPath] = report
        guard let data = try? encoder.encode(reports) else { return }
        try? data.write(to: redTeamURL, options: .atomic)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: redTeamURL.path
        )
    }

    public func loadPestState() -> PestState {
        guard let data = try? Data(contentsOf: pestURL),
              let state = try? decoder.decode(PestState.self, from: data) else {
            return .empty
        }
        return state
    }

    public func savePestState(_ state: PestState) {
        ensureDirectory()
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: pestURL, options: .atomic)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: pestURL.path
        )
    }

    public func loadNetworkState() -> NetworkState {
        guard let data = try? Data(contentsOf: networkURL),
              let state = try? decoder.decode(NetworkState.self, from: data) else {
            return .empty
        }
        return state
    }

    public func saveNetworkState(_ state: NetworkState) {
        ensureDirectory()
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: networkURL, options: .atomic)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: networkURL.path
        )
    }

    public func resetAll() {
        try? fileManager.removeItem(at: settingsURL)
        try? fileManager.removeItem(at: reportURL)
        try? fileManager.removeItem(at: redTeamURL)
        try? fileManager.removeItem(at: pestURL)
        try? fileManager.removeItem(at: networkURL)
    }

    private func ensureDirectory() {
        try? fileManager.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
    }
}
