import Foundation

public enum PestFindingSource: String, Codable, Sendable {
    case local
    case ia
}

public struct PestFinding: Codable, Identifiable, Sendable {
    public var severity: RiskLevel
    public var title: String
    public var checkID: String
    public var category: String
    public var nuclei: String?
    public var file: String
    public var line: Int?
    public var evidence: String
    public var impact: String
    public var recommendation: String
    public var fixPrompt: String
    public var confidence: String
    public var source: PestFindingSource

    public var id: String {
        "\(checkID)|\(file)|\(line ?? 0)|\(title)"
    }

    public var location: String {
        guard let line else { return file }
        return "\(file):\(line)"
    }

    public init(
        severity: RiskLevel,
        title: String,
        checkID: String,
        category: String,
        nuclei: String? = nil,
        file: String,
        line: Int?,
        evidence: String,
        impact: String,
        recommendation: String,
        fixPrompt: String,
        confidence: String,
        source: PestFindingSource
    ) {
        self.severity = severity
        self.title = title
        self.checkID = checkID
        self.category = category
        self.nuclei = nuclei
        self.file = file
        self.line = line
        self.evidence = evidence
        self.impact = impact
        self.recommendation = recommendation
        self.fixPrompt = fixPrompt
        self.confidence = confidence
        self.source = source
    }
}

public struct PestResumeState: Codable, Sendable {
    public var startedAt: Date
    public var processedPaths: [String]
    public var findings: [PestFinding]
    public var summaryParts: [String]
    public var limitations: [String]
    public var checksApplied: [String]
    public var filesAnalyzed: Int
    public var bytesAnalyzed: Int
    public var chunksAnalyzed: Int
    public var llmUsed: Bool
    public var routineID: UUID?

    public init(
        startedAt: Date,
        processedPaths: [String],
        findings: [PestFinding],
        summaryParts: [String],
        limitations: [String],
        checksApplied: [String],
        filesAnalyzed: Int,
        bytesAnalyzed: Int,
        chunksAnalyzed: Int,
        llmUsed: Bool,
        routineID: UUID?
    ) {
        self.startedAt = startedAt
        self.processedPaths = processedPaths
        self.findings = findings
        self.summaryParts = summaryParts
        self.limitations = limitations
        self.checksApplied = checksApplied
        self.filesAnalyzed = filesAnalyzed
        self.bytesAnalyzed = bytesAnalyzed
        self.chunksAnalyzed = chunksAnalyzed
        self.llmUsed = llmUsed
        self.routineID = routineID
    }
}

public struct PestReport: Codable, Identifiable, Sendable {
    public var id: UUID
    public var projectPath: String
    public var projectName: String
    public var startedAt: Date
    public var finishedAt: Date
    public var summary: String
    public var findings: [PestFinding]
    public var filesAnalyzed: Int
    public var bytesAnalyzed: Int
    public var chunksAnalyzed: Int
    public var checksApplied: [String]
    public var limitations: [String]
    public var llmUsed: Bool
    public var paused: Bool
    public var pauseReason: String?
    public var resumeState: PestResumeState?
    public var memoryBudgetBytes: UInt64
    public var availableMemoryAtStart: UInt64
    public var diskAvailableAtStart: Int64?

    public init(
        id: UUID = UUID(),
        projectPath: String,
        projectName: String,
        startedAt: Date,
        finishedAt: Date,
        summary: String,
        findings: [PestFinding],
        filesAnalyzed: Int,
        bytesAnalyzed: Int,
        chunksAnalyzed: Int,
        checksApplied: [String],
        limitations: [String],
        llmUsed: Bool,
        paused: Bool = false,
        pauseReason: String? = nil,
        resumeState: PestResumeState? = nil,
        memoryBudgetBytes: UInt64 = 0,
        availableMemoryAtStart: UInt64 = 0,
        diskAvailableAtStart: Int64? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
        self.projectName = projectName
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.summary = summary
        self.findings = findings
        self.filesAnalyzed = filesAnalyzed
        self.bytesAnalyzed = bytesAnalyzed
        self.chunksAnalyzed = chunksAnalyzed
        self.checksApplied = checksApplied
        self.limitations = limitations
        self.llmUsed = llmUsed
        self.paused = paused
        self.pauseReason = pauseReason
        self.resumeState = resumeState
        self.memoryBudgetBytes = memoryBudgetBytes
        self.availableMemoryAtStart = availableMemoryAtStart
        self.diskAvailableAtStart = diskAvailableAtStart
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
}

public struct PestProgress: Sendable {
    public var phase: String
    public var detail: String
    public var fraction: Double
    public var availableMemoryBytes: UInt64?
    public var budgetBytes: UInt64?

    public init(
        phase: String,
        detail: String,
        fraction: Double,
        availableMemoryBytes: UInt64? = nil,
        budgetBytes: UInt64? = nil
    ) {
        self.phase = phase
        self.detail = detail
        self.fraction = fraction
        self.availableMemoryBytes = availableMemoryBytes
        self.budgetBytes = budgetBytes
    }
}

public struct PestLLMResult: Sendable {
    public var summary: String
    public var findings: [PestFinding]
    public var limitations: [String]

    public init(summary: String, findings: [PestFinding], limitations: [String]) {
        self.summary = summary
        self.findings = findings
        self.limitations = limitations
    }
}

public enum PestError: Error, LocalizedError {
    case projectNotFound
    case noFiles
    case insufficientMemory(String)
    case insufficientDisk(String)
    case analysisFailed(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "A pasta do projeto não existe mais."
        case .noFiles:
            return "Nenhum arquivo de código legível foi encontrado neste projeto."
        case .insufficientMemory(let detail), .insufficientDisk(let detail):
            return detail
        case .analysisFailed(let detail):
            return detail
        }
    }
}
