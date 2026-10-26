import Foundation

public enum RiskLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case critical
    case high
    case medium
    case low
    case unknown

    public var rank: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .unknown: return 0
        }
    }

    public var label: String {
        switch self {
        case .critical: return "Crítica"
        case .high: return "Alta"
        case .medium: return "Média"
        case .low: return "Baixa"
        case .unknown: return "Indefinida"
        }
    }

    public var shortLabel: String {
        label.uppercased()
    }

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public static func from(cvss: Double?, isKEV: Bool = false) -> RiskLevel {
        if isKEV { return .critical }
        guard let cvss else { return .unknown }
        if cvss >= 9 { return .critical }
        if cvss >= 7 { return .high }
        if cvss >= 4 { return .medium }
        if cvss > 0 { return .low }
        return .unknown
    }
}

public struct MonitoredFolder: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var path: String
    public var addedAt: Date
    public var bookmarkData: Data?

    public init(
        id: UUID = UUID(),
        path: String,
        addedAt: Date = Date(),
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.path = path
        self.addedAt = addedAt
        self.bookmarkData = bookmarkData
    }

    public var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    public var displayName: String {
        let name = url.lastPathComponent
        return name.isEmpty ? path : name
    }
}

public struct AppSettings: Codable, Sendable {
    public var folders: [MonitoredFolder]
    public var excludedPaths: [String]
    public var scheduleEnabled: Bool
    public var scheduleHour: Int
    public var scheduleMinute: Int
    public var hasCompletedOnboarding: Bool
    public var notifyOnFindings: Bool
    public var lastScanAt: Date?

    public init(
        folders: [MonitoredFolder] = [],
        excludedPaths: [String] = [],
        scheduleEnabled: Bool = true,
        scheduleHour: Int = 9,
        scheduleMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        notifyOnFindings: Bool = true,
        lastScanAt: Date? = nil
    ) {
        self.folders = folders
        self.excludedPaths = excludedPaths
        self.scheduleEnabled = scheduleEnabled
        self.scheduleHour = scheduleHour
        self.scheduleMinute = scheduleMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notifyOnFindings = notifyOnFindings
        self.lastScanAt = lastScanAt
    }

    private enum CodingKeys: String, CodingKey {
        case folders
        case excludedPaths
        case scheduleEnabled
        case scheduleHour
        case scheduleMinute
        case hasCompletedOnboarding
        case notifyOnFindings
        case lastScanAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folders = try container.decodeIfPresent([MonitoredFolder].self, forKey: .folders) ?? []
        excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        scheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? true
        scheduleHour = try container.decodeIfPresent(Int.self, forKey: .scheduleHour) ?? 9
        scheduleMinute = try container.decodeIfPresent(Int.self, forKey: .scheduleMinute) ?? 0
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        notifyOnFindings = try container.decodeIfPresent(Bool.self, forKey: .notifyOnFindings) ?? true
        lastScanAt = try container.decodeIfPresent(Date.self, forKey: .lastScanAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(folders, forKey: .folders)
        try container.encode(excludedPaths, forKey: .excludedPaths)
        try container.encode(scheduleEnabled, forKey: .scheduleEnabled)
        try container.encode(scheduleHour, forKey: .scheduleHour)
        try container.encode(scheduleMinute, forKey: .scheduleMinute)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(notifyOnFindings, forKey: .notifyOnFindings)
        try container.encodeIfPresent(lastScanAt, forKey: .lastScanAt)
    }

    public var scheduleLabel: String {
        String(format: "%02d:%02d", scheduleHour, scheduleMinute)
    }

    public var scheduleDateToday: Date? {
        Calendar.current.date(
            bySettingHour: scheduleHour,
            minute: scheduleMinute,
            second: 0,
            of: Date()
        )
    }
}

public struct ProjectRef: Codable, Identifiable, Hashable, Sendable {
    public var path: String
    public var name: String
    public var lockfiles: [String]
    public var ecosystems: [String]

    public var id: String { path }

    public init(
        path: String,
        name: String,
        lockfiles: [String],
        ecosystems: [String]
    ) {
        self.path = path
        self.name = name
        self.lockfiles = lockfiles
        self.ecosystems = ecosystems
    }

    public var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}

public struct DependencyFinding: Codable, Identifiable, Hashable, Sendable {
    public var projectPath: String
    public var cveID: String
    public var title: String
    public var packageName: String
    public var installedVersion: String
    public var ecosystem: String
    public var cvss: Double?
    public var severity: RiskLevel
    public var url: String
    public var summary: String?
    public var fixedVersion: String?
    public var isKEV: Bool
    public var referenceURLs: [String]
    public var lockfile: String?

    public var id: String {
        "\(projectPath)|\(cveID)|\(packageName)|\(installedVersion)"
    }

    public init(
        projectPath: String,
        cveID: String,
        title: String,
        packageName: String,
        installedVersion: String,
        ecosystem: String,
        cvss: Double?,
        severity: RiskLevel,
        url: String,
        summary: String? = nil,
        fixedVersion: String? = nil,
        isKEV: Bool = false,
        referenceURLs: [String] = [],
        lockfile: String? = nil
    ) {
        self.projectPath = projectPath
        self.cveID = cveID
        self.title = title
        self.packageName = packageName
        self.installedVersion = installedVersion
        self.ecosystem = ecosystem
        self.cvss = cvss
        self.severity = severity
        self.url = url
        self.summary = summary
        self.fixedVersion = fixedVersion
        self.isKEV = isKEV
        self.referenceURLs = referenceURLs
        self.lockfile = lockfile
    }
}

public struct PackageAggregate: Identifiable, Hashable, Sendable {
    public var name: String
    public var installedVersion: String
    public var ecosystem: String
    public var fixedVersion: String?
    public var severity: RiskLevel
    public var findings: [DependencyFinding]

    public var id: String {
        "\(ecosystem)|\(name)|\(installedVersion)"
    }

    public var highestCVSS: Double? {
        findings.compactMap(\.cvss).max()
    }

    public var hasKEV: Bool {
        findings.contains { $0.isKEV }
    }

    public var cveIDs: [String] {
        Array(Set(findings.map(\.cveID))).sorted()
    }

    public init(
        name: String,
        installedVersion: String,
        ecosystem: String,
        fixedVersion: String?,
        severity: RiskLevel,
        findings: [DependencyFinding]
    ) {
        self.name = name
        self.installedVersion = installedVersion
        self.ecosystem = ecosystem
        self.fixedVersion = fixedVersion
        self.severity = severity
        self.findings = findings
    }
}

public struct ProjectAlert: Codable, Identifiable, Sendable {
    public var project: ProjectRef
    public var findings: [DependencyFinding]
    public var risk: RiskLevel
    public var headline: String
    public var diagnosis: String
    public var recommendation: String
    public var fixPrompt: String
    public var llmUsed: Bool
    public var generatedAt: Date

    public var id: String { project.path }

    public var packageCount: Int {
        Dictionary(grouping: findings, by: {
            "\($0.ecosystem)|\($0.packageName)|\($0.installedVersion)"
        }).count
    }

    public var highestCVSS: Double? {
        findings.compactMap(\.cvss).max()
    }

    public var hasKEV: Bool {
        findings.contains { $0.isKEV }
    }

    public var packageAggregates: [PackageAggregate] {
        let grouped = Dictionary(grouping: findings) {
            "\($0.ecosystem)|\($0.packageName)|\($0.installedVersion)"
        }

        return grouped.values.map { items in
            let sorted = items.sorted { lhs, rhs in
                if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
                return (lhs.cvss ?? 0) > (rhs.cvss ?? 0)
            }
            let severity = sorted.map(\.severity).max() ?? .unknown
            let fixed = sorted.compactMap(\.fixedVersion).max(by: Semver.lessThan)
            return PackageAggregate(
                name: sorted.first?.packageName ?? "pacote",
                installedVersion: sorted.first?.installedVersion ?? "?",
                ecosystem: sorted.first?.ecosystem ?? "npm",
                fixedVersion: fixed,
                severity: severity,
                findings: sorted
            )
        }
        .sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            if lhs.findings.count != rhs.findings.count {
                return lhs.findings.count > rhs.findings.count
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public init(
        project: ProjectRef,
        findings: [DependencyFinding],
        risk: RiskLevel,
        headline: String,
        diagnosis: String,
        recommendation: String,
        fixPrompt: String,
        llmUsed: Bool,
        generatedAt: Date = Date()
    ) {
        self.project = project
        self.findings = findings
        self.risk = risk
        self.headline = headline
        self.diagnosis = diagnosis
        self.recommendation = recommendation
        self.fixPrompt = fixPrompt
        self.llmUsed = llmUsed
        self.generatedAt = generatedAt
    }
}

public struct ScanReport: Codable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var finishedAt: Date
    public var folders: [String]
    public var projectsScanned: Int
    public var lockfilesChecked: Int
    public var alerts: [ProjectAlert]
    public var summary: String
    public var nextSteps: [String]
    public var llmUsed: Bool
    public var warnings: [String]

    public var totalFindings: Int {
        alerts.reduce(0) { $0 + $1.findings.count }
    }

    public var totalPackages: Int {
        alerts.reduce(0) { $0 + $1.packageCount }
    }

    public var criticalCount: Int {
        alerts.reduce(0) { partial, alert in
            partial + alert.findings.filter { $0.severity == .critical }.count
        }
    }

    public var highCount: Int {
        alerts.reduce(0) { partial, alert in
            partial + alert.findings.filter { $0.severity == .high }.count
        }
    }

    public var risk: RiskLevel {
        alerts.map(\.risk).max() ?? .unknown
    }

    public var hasFindings: Bool {
        totalFindings > 0
    }

    public var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        folders: [String],
        projectsScanned: Int,
        lockfilesChecked: Int,
        alerts: [ProjectAlert],
        summary: String,
        nextSteps: [String] = [],
        llmUsed: Bool,
        warnings: [String]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.folders = folders
        self.projectsScanned = projectsScanned
        self.lockfilesChecked = lockfilesChecked
        self.alerts = alerts
        self.summary = summary
        self.nextSteps = nextSteps
        self.llmUsed = llmUsed
        self.warnings = warnings
    }
}

public struct PackageCoordinate: Hashable, Sendable {
    public var ecosystem: String
    public var name: String
    public var version: String

    public init(ecosystem: String, name: String, version: String) {
        self.ecosystem = ecosystem
        self.name = name
        self.version = version
    }
}

public struct LockfilePayload: Sendable {
    public var name: String
    public var content: String?
    public var packages: [PackageCoordinate]
    public var note: String?

    public init(
        name: String,
        content: String? = nil,
        packages: [PackageCoordinate] = [],
        note: String? = nil
    ) {
        self.name = name
        self.content = content
        self.packages = packages
        self.note = note
    }
}

public struct ScannedProject: Identifiable, Sendable {
    public var ref: ProjectRef
    public var payloads: [LockfilePayload]

    public var id: String { ref.path }

    public init(ref: ProjectRef, payloads: [LockfilePayload]) {
        self.ref = ref
        self.payloads = payloads
    }
}

public struct ScanProgress: Sendable {
    public var phase: String
    public var detail: String
    public var fraction: Double?

    public init(phase: String, detail: String, fraction: Double? = nil) {
        self.phase = phase
        self.detail = detail
        self.fraction = fraction
    }
}
