import Foundation

public struct NetworkAuditContext: Codable, Sendable {
    public var isPublicNetwork: Bool

    public init(isPublicNetwork: Bool = false) {
        self.isPublicNetwork = isPublicNetwork
    }
}

public enum NetworkFeatureSource: String, Codable, Sendable {
    case wifi
    case gateway
    case mac
    case devices
    case services
    case dns
}

public struct NetworkDevice: Codable, Identifiable, Hashable, Sendable {
    public var ip: String
    public var mac: String
    public var isGateway: Bool
    public var macKind: String

    public var id: String { "\(ip)|\(mac)" }

    public init(ip: String, mac: String, isGateway: Bool, macKind: String) {
        self.ip = ip
        self.mac = mac
        self.isGateway = isGateway
        self.macKind = macKind
    }
}

public struct NetworkGatewayProbe: Codable, Sendable {
    public var scheme: String
    public var reachable: Bool
    public var statusCode: Int?
    public var server: String?
    public var title: String?
    public var finalURL: String?
    public var hasLoginForm: Bool
    public var usesBasicAuth: Bool
    public var redirectsToHTTPS: Bool
    public var certificateProblem: Bool
    public var error: String?

    public init(
        scheme: String,
        reachable: Bool,
        statusCode: Int? = nil,
        server: String? = nil,
        title: String? = nil,
        finalURL: String? = nil,
        hasLoginForm: Bool = false,
        usesBasicAuth: Bool = false,
        redirectsToHTTPS: Bool = false,
        certificateProblem: Bool = false,
        error: String? = nil
    ) {
        self.scheme = scheme
        self.reachable = reachable
        self.statusCode = statusCode
        self.server = server
        self.title = title
        self.finalURL = finalURL
        self.hasLoginForm = hasLoginForm
        self.usesBasicAuth = usesBasicAuth
        self.redirectsToHTTPS = redirectsToHTTPS
        self.certificateProblem = certificateProblem
        self.error = error
    }
}

public struct NetworkListeningService: Codable, Identifiable, Hashable, Sendable {
    public var process: String
    public var port: Int
    public var bind: String
    public var exposedToLAN: Bool

    public var id: String { "\(process)|\(port)|\(bind)" }

    public init(process: String, port: Int, bind: String, exposedToLAN: Bool) {
        self.process = process
        self.port = port
        self.bind = bind
        self.exposedToLAN = exposedToLAN
    }
}

public struct NetworkSnapshot: Codable, Sendable {
    public var capturedAt: Date
    public var hostName: String
    public var interfaceName: String?
    public var ssid: String?
    public var bssidMasked: String?
    public var securityMode: String?
    public var securityLabel: String
    public var channel: String?
    public var signal: String?
    public var countryCode: String?
    public var gateway: String?
    public var dnsServers: [String]
    public var vpnActive: Bool
    public var vpnInterfaces: [String]
    public var devices: [NetworkDevice]
    public var gatewayHTTP: NetworkGatewayProbe?
    public var gatewayHTTPS: NetworkGatewayProbe?
    public var listeningServices: [NetworkListeningService]
    public var firewallEnabled: Bool?
    public var firewallStealth: Bool?
    public var fileVaultEnabled: Bool?
    public var sipEnabled: Bool?
    public var gatekeeperEnabled: Bool?
    public var automaticUpdatesEnabled: Bool?
    public var context: NetworkAuditContext
    public var warnings: [String]

    public init(
        capturedAt: Date = Date(),
        hostName: String,
        interfaceName: String? = nil,
        ssid: String? = nil,
        bssidMasked: String? = nil,
        securityMode: String? = nil,
        securityLabel: String = "Não identificada",
        channel: String? = nil,
        signal: String? = nil,
        countryCode: String? = nil,
        gateway: String? = nil,
        dnsServers: [String] = [],
        vpnActive: Bool = false,
        vpnInterfaces: [String] = [],
        devices: [NetworkDevice] = [],
        gatewayHTTP: NetworkGatewayProbe? = nil,
        gatewayHTTPS: NetworkGatewayProbe? = nil,
        listeningServices: [NetworkListeningService] = [],
        firewallEnabled: Bool? = nil,
        firewallStealth: Bool? = nil,
        fileVaultEnabled: Bool? = nil,
        sipEnabled: Bool? = nil,
        gatekeeperEnabled: Bool? = nil,
        automaticUpdatesEnabled: Bool? = nil,
        context: NetworkAuditContext = NetworkAuditContext(),
        warnings: [String] = []
    ) {
        self.capturedAt = capturedAt
        self.hostName = hostName
        self.interfaceName = interfaceName
        self.ssid = ssid
        self.bssidMasked = bssidMasked
        self.securityMode = securityMode
        self.securityLabel = securityLabel
        self.channel = channel
        self.signal = signal
        self.countryCode = countryCode
        self.gateway = gateway
        self.dnsServers = dnsServers
        self.vpnActive = vpnActive
        self.vpnInterfaces = vpnInterfaces
        self.devices = devices
        self.gatewayHTTP = gatewayHTTP
        self.gatewayHTTPS = gatewayHTTPS
        self.listeningServices = listeningServices
        self.firewallEnabled = firewallEnabled
        self.firewallStealth = firewallStealth
        self.fileVaultEnabled = fileVaultEnabled
        self.sipEnabled = sipEnabled
        self.gatekeeperEnabled = gatekeeperEnabled
        self.automaticUpdatesEnabled = automaticUpdatesEnabled
        self.context = context
        self.warnings = warnings
    }
}

public struct NetworkFinding: Codable, Identifiable, Sendable {
    public var severity: RiskLevel
    public var title: String
    public var checkID: String
    public var category: String
    public var target: String
    public var evidence: String
    public var whatItMeans: String
    public var scenario: String
    public var likelihood: String
    public var recommendation: String
    public var fixPrompt: String
    public var source: NetworkFeatureSource

    public var id: String { "\(checkID)|\(target)|\(title)" }

    public init(
        severity: RiskLevel,
        title: String,
        checkID: String,
        category: String,
        target: String,
        evidence: String,
        whatItMeans: String,
        scenario: String,
        likelihood: String,
        recommendation: String,
        fixPrompt: String,
        source: NetworkFeatureSource
    ) {
        self.severity = severity
        self.title = title
        self.checkID = checkID
        self.category = category
        self.target = target
        self.evidence = evidence
        self.whatItMeans = whatItMeans
        self.scenario = scenario
        self.likelihood = likelihood
        self.recommendation = recommendation
        self.fixPrompt = fixPrompt
        self.source = source
    }
}

public enum NetworkScenarioStatus: String, Codable, Sendable {
    case confirmed
    case possible
    case notFound
    case unverified

    public var label: String {
        switch self {
        case .confirmed: return "Confirmado agora"
        case .possible: return "Possível no seu cenário"
        case .notFound: return "Não encontrado"
        case .unverified: return "Não foi possível verificar"
        }
    }
}

public struct NetworkScenario: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var status: NetworkScenarioStatus
    public var explanation: String
    public var whatCouldHappen: String
    public var protection: String
    public var basedOn: String

    public init(
        id: String,
        title: String,
        status: NetworkScenarioStatus,
        explanation: String,
        whatCouldHappen: String,
        protection: String,
        basedOn: String
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.explanation = explanation
        self.whatCouldHappen = whatCouldHappen
        self.protection = protection
        self.basedOn = basedOn
    }
}

public struct NetworkReport: Codable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var finishedAt: Date
    public var context: NetworkAuditContext
    public var snapshot: NetworkSnapshot
    public var summary: String
    public var assurance: String
    public var findings: [NetworkFinding]
    public var scenarios: [NetworkScenario]
    public var limitations: [String]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        context: NetworkAuditContext,
        snapshot: NetworkSnapshot,
        summary: String,
        assurance: String,
        findings: [NetworkFinding],
        scenarios: [NetworkScenario],
        limitations: [String]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.context = context
        self.snapshot = snapshot
        self.summary = summary
        self.assurance = assurance
        self.findings = findings
        self.scenarios = scenarios
        self.limitations = limitations
    }

    public var risk: RiskLevel {
        findings.map(\.severity).max() ?? .unknown
    }

    public var criticalCount: Int {
        findings.filter { $0.severity == .critical }.count
    }

    public var highCount: Int {
        findings.filter { $0.severity == .high }.count
    }

    public var exposedServices: [NetworkListeningService] {
        snapshot.listeningServices.filter(\.exposedToLAN)
    }
}

public struct NetworkState: Codable, Sendable {
    public var reports: [NetworkReport]
    public var lastRunAt: Date?
    public var updatedAt: Date

    public init(
        reports: [NetworkReport] = [],
        lastRunAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.reports = reports
        self.lastRunAt = lastRunAt
        self.updatedAt = updatedAt
    }

    public static var empty: NetworkState { NetworkState() }

    public mutating func addReport(_ report: NetworkReport, limit: Int = 10) {
        reports.removeAll { $0.id == report.id }
        reports.insert(report, at: 0)
        if reports.count > limit {
            reports.removeLast(reports.count - limit)
        }
        lastRunAt = report.finishedAt
        updatedAt = Date()
    }

    public var latest: NetworkReport? { reports.first }
}

public struct NetworkProgress: Sendable {
    public var phase: String
    public var detail: String
    public var fraction: Double

    public init(phase: String, detail: String, fraction: Double) {
        self.phase = phase
        self.detail = detail
        self.fraction = fraction
    }
}

public enum NetworkAuditError: Error, LocalizedError {
    case cancelled
    case commandFailed(String)
    case noNetwork

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Análise da rede cancelada."
        case .commandFailed(let message):
            return "Não consegui concluir a análise da rede: \(message)"
        case .noNetwork:
            return "Não encontrei uma conexão de rede ativa neste Mac."
        }
    }
}
