import Foundation

public struct RedTeamSourceFile: Codable, Identifiable, Sendable {
    public var path: String
    public var content: String
    public var bytes: Int

    public var id: String { path }

    public init(path: String, content: String, bytes: Int) {
        self.path = path
        self.content = content
        self.bytes = bytes
    }
}

public struct RedTeamFileRef: Codable, Identifiable, Hashable, Sendable {
    public var path: String
    public var bytes: Int

    public var id: String { path }

    public init(path: String, bytes: Int) {
        self.path = path
        self.bytes = bytes
    }
}

public struct RedTeamFinding: Codable, Identifiable, Sendable {
    public var severity: RiskLevel
    public var title: String
    public var file: String
    public var line: Int?
    public var evidence: String
    public var impact: String
    public var recommendation: String
    public var confidence: String

    public var id: String {
        "\(file)|\(line ?? 0)|\(title)"
    }

    public init(
        severity: RiskLevel,
        title: String,
        file: String,
        line: Int?,
        evidence: String,
        impact: String,
        recommendation: String,
        confidence: String
    ) {
        self.severity = severity
        self.title = title
        self.file = file
        self.line = line
        self.evidence = evidence
        self.impact = impact
        self.recommendation = recommendation
        self.confidence = confidence
    }

    public var location: String {
        guard let line else { return file }
        return "\(file):\(line)"
    }
}

public struct RedTeamResumeState: Codable, Sendable {
    public var startedAt: Date
    public var processedPaths: [String]
    public var findings: [RedTeamFinding]
    public var summaryParts: [String]
    public var limitations: [String]
    public var filesAnalyzed: Int
    public var bytesAnalyzed: Int
    public var chunksAnalyzed: Int
    public var routineID: UUID?

    public init(
        startedAt: Date,
        processedPaths: [String],
        findings: [RedTeamFinding],
        summaryParts: [String],
        limitations: [String],
        filesAnalyzed: Int,
        bytesAnalyzed: Int,
        chunksAnalyzed: Int,
        routineID: UUID?
    ) {
        self.startedAt = startedAt
        self.processedPaths = processedPaths
        self.findings = findings
        self.summaryParts = summaryParts
        self.limitations = limitations
        self.filesAnalyzed = filesAnalyzed
        self.bytesAnalyzed = bytesAnalyzed
        self.chunksAnalyzed = chunksAnalyzed
        self.routineID = routineID
    }
}

public struct RedTeamReport: Codable, Identifiable, Sendable {
    public var id: UUID
    public var projectPath: String
    public var projectName: String
    public var startedAt: Date
    public var finishedAt: Date
    public var summary: String
    public var findings: [RedTeamFinding]
    public var filesAnalyzed: Int
    public var bytesAnalyzed: Int
    public var chunksAnalyzed: Int
    public var limitations: [String]
    public var llmUsed: Bool
    public var paused: Bool
    public var pauseReason: String?
    public var resumeState: RedTeamResumeState?
    public var memoryBudgetBytes: Int?
    public var availableMemoryAtStart: Int?

    public init(
        id: UUID = UUID(),
        projectPath: String,
        projectName: String,
        startedAt: Date,
        finishedAt: Date,
        summary: String,
        findings: [RedTeamFinding],
        filesAnalyzed: Int,
        bytesAnalyzed: Int,
        chunksAnalyzed: Int,
        limitations: [String],
        llmUsed: Bool = true,
        paused: Bool = false,
        pauseReason: String? = nil,
        resumeState: RedTeamResumeState? = nil,
        memoryBudgetBytes: Int? = nil,
        availableMemoryAtStart: Int? = nil
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
        self.limitations = limitations
        self.llmUsed = llmUsed
        self.paused = paused
        self.pauseReason = pauseReason
        self.resumeState = resumeState
        self.memoryBudgetBytes = memoryBudgetBytes
        self.availableMemoryAtStart = availableMemoryAtStart
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectPath
        case projectName
        case startedAt
        case finishedAt
        case summary
        case findings
        case filesAnalyzed
        case bytesAnalyzed
        case chunksAnalyzed
        case limitations
        case llmUsed
        case paused
        case pauseReason
        case resumeState
        case memoryBudgetBytes
        case availableMemoryAtStart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        projectPath = try container.decode(String.self, forKey: .projectPath)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? "projeto"
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt) ?? Date()
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        findings = try container.decodeIfPresent([RedTeamFinding].self, forKey: .findings) ?? []
        filesAnalyzed = try container.decodeIfPresent(Int.self, forKey: .filesAnalyzed) ?? 0
        bytesAnalyzed = try container.decodeIfPresent(Int.self, forKey: .bytesAnalyzed) ?? 0
        chunksAnalyzed = try container.decodeIfPresent(Int.self, forKey: .chunksAnalyzed) ?? 0
        limitations = try container.decodeIfPresent([String].self, forKey: .limitations) ?? []
        llmUsed = try container.decodeIfPresent(Bool.self, forKey: .llmUsed) ?? true
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        pauseReason = try container.decodeIfPresent(String.self, forKey: .pauseReason)
        resumeState = try container.decodeIfPresent(RedTeamResumeState.self, forKey: .resumeState)
        memoryBudgetBytes = try container.decodeIfPresent(Int.self, forKey: .memoryBudgetBytes)
        availableMemoryAtStart = try container.decodeIfPresent(Int.self, forKey: .availableMemoryAtStart)
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

public struct RedTeamProgress: Sendable {
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

public struct RedTeamLLMResult: Sendable {
    public var summary: String
    public var findings: [RedTeamFinding]
    public var limitations: [String]

    public init(summary: String, findings: [RedTeamFinding], limitations: [String]) {
        self.summary = summary
        self.findings = findings
        self.limitations = limitations
    }
}

public struct RedTeamCollection: Sendable {
    public var files: [RedTeamSourceFile]
    public var warnings: [String]
    public var skippedFiles: Int
    public var totalBytes: Int

    public init(files: [RedTeamSourceFile], warnings: [String], skippedFiles: Int, totalBytes: Int) {
        self.files = files
        self.warnings = warnings
        self.skippedFiles = skippedFiles
        self.totalBytes = totalBytes
    }
}

public struct RedTeamInventory: Sendable {
    public var files: [RedTeamFileRef]
    public var warnings: [String]
    public var skippedFiles: Int
    public var totalBytes: Int

    public init(files: [RedTeamFileRef], warnings: [String], skippedFiles: Int, totalBytes: Int) {
        self.files = files
        self.warnings = warnings
        self.skippedFiles = skippedFiles
        self.totalBytes = totalBytes
    }
}

public enum RedTeamError: Error, LocalizedError {
    case projectNotFound
    case projectExcluded
    case noFiles
    case insufficientMemory(String)
    case insufficientDisk(String)
    case analysisFailed(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "A pasta do projeto não existe mais."
        case .projectExcluded:
            return "Este projeto está ignorado em Ajustes > Pastas. Reative a pasta para analisar."
        case .noFiles:
            return "Nenhum arquivo de código legível foi encontrado neste projeto."
        case .insufficientMemory(let detail):
            return detail
        case .insufficientDisk(let detail):
            return detail
        case .analysisFailed(let detail):
            return detail
        }
    }
}

public struct RedTeamBudget: Sendable, Equatable {
    public var maxFiles: Int
    public var maxFileBytes: Int
    public var maxTotalBytes: Int
    public var maxChunkBytes: Int
    public var maxChunks: Int
    public var maxRSSGrowthBytes: UInt64
    public var minimumAvailableBytes: UInt64

    public init(
        maxFiles: Int,
        maxFileBytes: Int,
        maxTotalBytes: Int,
        maxChunkBytes: Int,
        maxChunks: Int,
        maxRSSGrowthBytes: UInt64,
        minimumAvailableBytes: UInt64
    ) {
        self.maxFiles = maxFiles
        self.maxFileBytes = maxFileBytes
        self.maxTotalBytes = maxTotalBytes
        self.maxChunkBytes = maxChunkBytes
        self.maxChunks = maxChunks
        self.maxRSSGrowthBytes = maxRSSGrowthBytes
        self.minimumAvailableBytes = minimumAvailableBytes
    }
}

/// O Red Teaming segura pouca coisa em memória: a lista de arquivos primeiro,
/// um bloco de cada vez depois. O orçamento cai junto com a memória livre.
public enum RedTeamMemoryGuard {
    public static let minimumAvailableBytes = PestMemoryGuard.minimumAvailableBytes
    public static let minimumDiskBytes = PestMemoryGuard.minimumDiskBytes
    public static let hardRSSGrowthCap: UInt64 = 96 * 1024 * 1024
    public static let minimumRSSGrowth: UInt64 = 24 * 1024 * 1024

    public static func budget(for snapshot: PestMemorySnapshot) -> RedTeamBudget? {
        guard snapshot.availableBytes >= minimumAvailableBytes else { return nil }
        guard (snapshot.diskAvailableBytes ?? Int64.max) >= minimumDiskBytes else { return nil }

        let quarter = snapshot.availableBytes / 4
        let growth = max(minimumRSSGrowth, min(hardRSSGrowthCap, quarter))
        let fullRun = snapshot.availableBytes >= 512 * 1024 * 1024

        return RedTeamBudget(
            maxFiles: fullRun ? 90 : 40,
            maxFileBytes: fullRun ? 48_000 : 32_000,
            maxTotalBytes: fullRun ? 700_000 : 320_000,
            maxChunkBytes: fullRun ? 60_000 : 34_000,
            maxChunks: fullRun ? 14 : 8,
            maxRSSGrowthBytes: growth,
            minimumAvailableBytes: minimumAvailableBytes
        )
    }

    public static func pauseReason(
        baselineRSS: UInt64,
        budget: RedTeamBudget
    ) -> String? {
        let current = PestMemoryGuard.snapshot()
        if current.availableBytes < budget.minimumAvailableBytes {
            return "O Mac está com \(PestMemoryGuard.formatBytes(current.availableBytes)) de memória disponível; o mínimo seguro para o Red Teaming é \(PestMemoryGuard.formatBytes(budget.minimumAvailableBytes))."
        }
        let growth = current.residentBytes > baselineRSS
            ? current.residentBytes - baselineRSS
            : 0
        if growth > budget.maxRSSGrowthBytes {
            return "O Red Teaming chegou a \(PestMemoryGuard.formatBytes(growth)) de memória adicional, acima do limite de \(PestMemoryGuard.formatBytes(budget.maxRSSGrowthBytes))."
        }
        if let disk = current.diskAvailableBytes, disk < minimumDiskBytes {
            return "O disco está com apenas \(PestMemoryGuard.formatBytes(UInt64(max(disk, 0)))) livres; o mínimo para salvar o relatório é \(PestMemoryGuard.formatBytes(UInt64(minimumDiskBytes)))."
        }
        return nil
    }
}

public struct RedTeamCollector: Sendable {
    public var maxFiles: Int
    public var maxFileBytes: Int
    public var maxTotalBytes: Int
    public var maxDepth: Int

    public init(
        maxFiles: Int = 90,
        maxFileBytes: Int = 48_000,
        maxTotalBytes: Int = 700_000,
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
        "dockerfile", "conf", "config", "ini", "env.example"
    ]

    private static let allowedNames: Set<String> = [
        "Dockerfile", "Makefile", "Procfile", "Gemfile", "Rakefile",
        "Vagrantfile", "package.json", "pyproject.toml", "Cargo.toml",
        "go.mod", "composer.json", "deno.json", "tsconfig.json"
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

    /// Lista os arquivos elegíveis sem ler o conteúdo. É a etapa que define o
    /// teto de memória do Red Teaming.
    public func inventory(
        projectPath: String,
        excludedPaths: [String] = []
    ) throws -> RedTeamInventory {
        let root = URL(fileURLWithPath: projectPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RedTeamError.projectNotFound
        }

        let exclusions = PathExclusions.normalized(excludedPaths)
        if PathExclusions.contains(root, in: exclusions) {
            throw RedTeamError.projectExcluded
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ]
        var files: [RedTeamFileRef] = []
        var warnings: [String] = []
        var skipped = 0
        var totalBytes = 0

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                warnings.append("Não consegui ler \(url.lastPathComponent): \(error.localizedDescription)")
                return true
            }
        ) else {
            throw RedTeamError.noFiles
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
            if size > maxFileBytes {
                warnings.append("\(name) foi ignorado por ter mais de \(maxFileBytes / 1000) KB.")
                skipped += 1
                continue
            }
            if totalBytes + size > maxTotalBytes {
                warnings.append("O limite de \(maxTotalBytes / 1000) KB de código por análise foi atingido.")
                break
            }
            if files.count >= maxFiles {
                warnings.append("O limite de \(maxFiles) arquivos por análise foi atingido.")
                break
            }

            files.append(RedTeamFileRef(path: relativePath(of: url, root: root), bytes: size))
            totalBytes += size
        }

        if skipped > 0 {
            warnings.append("\(skipped) arquivo(s) sensível(is), binário(s) ou grande(s) ficaram fora da análise.")
        }

        return RedTeamInventory(
            files: files,
            warnings: warnings,
            skippedFiles: skipped,
            totalBytes: totalBytes
        )
    }

    /// Conveniência para leituras completas (testes e usos pequenos).
    public func collect(
        projectPath: String,
        excludedPaths: [String] = []
    ) throws -> RedTeamCollection {
        let inventory = try inventory(projectPath: projectPath, excludedPaths: excludedPaths)
        let reader = RedTeamReader()
        var files: [RedTeamSourceFile] = []
        for ref in inventory.files {
            if let source = try? reader.read(
                ref,
                projectPath: projectPath,
                maxBytes: maxFileBytes
            ) {
                files.append(source)
            }
        }
        var warnings = inventory.warnings
        let redactedCount = files.filter { $0.content.contains("[REDACTED]") }.count
        if redactedCount > 0 {
            warnings.append("Valores com aparência de segredo foram redigidos em \(redactedCount) arquivo(s).")
        }
        return RedTeamCollection(
            files: files,
            warnings: warnings,
            skippedFiles: inventory.skippedFiles,
            totalBytes: inventory.totalBytes
        )
    }

    private func relativePath(of url: URL, root: URL) -> String {
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let filePath = url.standardizedFileURL.resolvingSymlinksInPath().path
        if filePath.hasPrefix(rootPrefix) {
            return String(filePath.dropFirst(rootPrefix.count))
        }
        return url.lastPathComponent
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

public struct RedTeamReader: Sendable {
    public init() {}

    public func read(
        _ ref: RedTeamFileRef,
        projectPath: String,
        maxBytes: Int
    ) throws -> RedTeamSourceFile? {
        let root = URL(fileURLWithPath: projectPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let url = root.appendingPathComponent(ref.path)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { return nil }
        let size = values.fileSize ?? ref.bytes
        guard size <= maxBytes else { return nil }

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              !data.contains(0),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        return RedTeamSourceFile(
            path: ref.path,
            content: Self.redact(text),
            bytes: data.count
        )
    }

    private static func redact(_ text: String) -> String {
        var value = text
        let rules: [(String, String)] = [
            (#"(?i)(api[_-]?key|secret|token|password|passwd|client[_-]?secret|private[_-]?key)\s*[:=]\s*["']?[^"'\s,}]+"#, "$1 = \"[REDACTED]\""),
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
        return value
    }
}

public final class RedTeamService: @unchecked Sendable {
    private let collector: RedTeamCollector
    private let reader: RedTeamReader
    private let llmClient: LLMClient

    public init(
        collector: RedTeamCollector = RedTeamCollector(),
        reader: RedTeamReader = RedTeamReader(),
        llmClient: LLMClient = LLMClient()
    ) {
        self.collector = collector
        self.reader = reader
        self.llmClient = llmClient
    }

    public func analyze(
        project: ProjectRef,
        routineID: UUID? = nil,
        resume: RedTeamResumeState? = nil,
        excludedPaths: [String] = [],
        progress: @escaping @Sendable (RedTeamProgress) -> Void
    ) async throws -> RedTeamReport {
        let startedAt = resume?.startedAt ?? Date()
        let startSnapshot = PestMemoryGuard.snapshot()
        guard startSnapshot.availableBytes >= RedTeamMemoryGuard.minimumAvailableBytes else {
            throw RedTeamError.insufficientMemory(
                "O Mac tem \(PestMemoryGuard.formatBytes(startSnapshot.availableBytes)) de memória disponível. Feche apps pesados e tente de novo; o mínimo seguro para o Red Teaming é \(PestMemoryGuard.formatBytes(RedTeamMemoryGuard.minimumAvailableBytes))."
            )
        }
        if let disk = startSnapshot.diskAvailableBytes,
           disk < RedTeamMemoryGuard.minimumDiskBytes {
            throw RedTeamError.insufficientDisk(
                "O disco tem \(PestMemoryGuard.formatBytes(UInt64(max(disk, 0)))) livres. Libere pelo menos \(PestMemoryGuard.formatBytes(UInt64(RedTeamMemoryGuard.minimumDiskBytes))) para o Red Teaming montar o relatório."
            )
        }
        guard let budget = RedTeamMemoryGuard.budget(for: startSnapshot) else {
            throw RedTeamError.insufficientMemory(
                "O Red Teaming não conseguiu reservar um orçamento seguro de memória. Feche apps pesados e tente de novo."
            )
        }

        let collector = RedTeamCollector(
            maxFiles: budget.maxFiles,
            maxFileBytes: budget.maxFileBytes,
            maxTotalBytes: budget.maxTotalBytes
        )

        progress(
            RedTeamProgress(
                phase: resume == nil ? "Lendo arquivos" : "Retomando",
                detail: resume == nil
                    ? "Mapeando o projeto com orçamento de \(PestMemoryGuard.formatBytes(UInt64(budget.maxTotalBytes)))."
                    : "Retomando a análise pausada.",
                fraction: 0.04,
                availableMemoryBytes: startSnapshot.availableBytes,
                budgetBytes: budget.maxRSSGrowthBytes
            )
        )

        let inventory = try collector.inventory(
            projectPath: project.path,
            excludedPaths: excludedPaths
        )
        guard !inventory.files.isEmpty else {
            throw RedTeamError.noFiles
        }

        var findings = resume?.findings ?? []
        var summaries = resume?.summaryParts ?? []
        var limitations = resume?.limitations ?? []
        limitations.append(contentsOf: inventory.warnings)
        limitations.append(
            "A análise cobre apenas arquivos de texto enviados; binários, dependências instaladas, lockfiles e arquivos grandes ficaram de fora."
        )
        limitations.append(
            "Limites desta execução: até \(budget.maxFiles) arquivos, \(PestMemoryGuard.formatBytes(UInt64(budget.maxTotalBytes))) de código e \(PestMemoryGuard.formatBytes(budget.maxRSSGrowthBytes)) de memória adicional."
        )

        let processed = Set(resume?.processedPaths ?? [])
        let remaining = inventory.files.filter { !processed.contains($0.path) }
        let chunks = Self.chunk(remaining, maxBytes: budget.maxChunkBytes)
        let totalChunks = chunks.count
        var processedPaths = resume?.processedPaths ?? []
        var filesAnalyzed = resume?.filesAnalyzed ?? 0
        var bytesAnalyzed = resume?.bytesAnalyzed ?? 0
        var chunksAnalyzed = resume?.chunksAnalyzed ?? 0
        var paused = false
        var pauseReason: String? = nil

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            if let reason = RedTeamMemoryGuard.pauseReason(
                baselineRSS: startSnapshot.residentBytes,
                budget: budget
            ) {
                pauseReason = reason
                paused = true
                break
            }

            let fraction = 0.10 + (Double(index) / Double(max(totalChunks, 1))) * 0.78
            progress(
                RedTeamProgress(
                    phase: "Analisando bloco \(index + 1) de \(totalChunks)",
                    detail: "\(chunk.count) arquivo(s) neste bloco. Isso pode levar alguns minutos.",
                    fraction: fraction,
                    availableMemoryBytes: PestMemoryGuard.snapshot().availableBytes,
                    budgetBytes: budget.maxRSSGrowthBytes
                )
            )

            var sources: [RedTeamSourceFile] = []
            var chunkBytes = 0
            for ref in chunk {
                if let source = try? reader.read(
                    ref,
                    projectPath: project.path,
                    maxBytes: budget.maxFileBytes
                ) {
                    sources.append(source)
                    chunkBytes += source.bytes
                } else {
                    limitations.append("Não consegui ler \(ref.path) nesta rodada.")
                }
            }
            guard !sources.isEmpty else { continue }

            let result = try await llmClient.analyzeRedTeam(
                project: project,
                files: sources,
                chunkIndex: index + 1,
                chunkCount: totalChunks
            )
            findings.append(contentsOf: result.findings)
            if !result.summary.isEmpty {
                summaries.append(result.summary)
            }
            limitations.append(contentsOf: result.limitations)

            processedPaths.append(contentsOf: chunk.map(\.path))
            filesAnalyzed += sources.count
            bytesAnalyzed += chunkBytes
            chunksAnalyzed += 1
            sources.removeAll(keepingCapacity: false)

            if let reason = RedTeamMemoryGuard.pauseReason(
                baselineRSS: startSnapshot.residentBytes,
                budget: budget
            ) {
                paused = true
                pauseReason = reason
                break
            }
        }

        if !paused, totalChunks > 0, chunksAnalyzed < totalChunks {
            limitations.append("A análise parou antes do fim do orçamento de blocos.")
        }

        progress(
            RedTeamProgress(
                phase: "Consolidando",
                detail: "Removendo duplicatas e ordenando os achados…",
                fraction: 0.94,
                availableMemoryBytes: PestMemoryGuard.snapshot().availableBytes,
                budgetBytes: budget.maxRSSGrowthBytes
            )
        )

        let uniqueFindings = Self.deduplicated(findings)
        let summary = summaries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let finalSummary: String
        if paused {
            finalSummary = summary.isEmpty
                ? "O Red Teaming pausou para proteger a memória do Mac antes de concluir."
                : String(summary.prefix(2_400))
        } else {
            finalSummary = summary.isEmpty
                ? "A análise não encontrou falhas de segurança no código enviado."
                : String(summary.prefix(2_400))
        }

        if chunks.count > 1 {
            limitations.append("O projeto foi dividido em \(chunks.count) blocos para caber no contexto da LLM.")
        }

        let resumeState = paused
            ? RedTeamResumeState(
                startedAt: startedAt,
                processedPaths: processedPaths,
                findings: uniqueFindings,
                summaryParts: summaries,
                limitations: Self.unique(limitations),
                filesAnalyzed: filesAnalyzed,
                bytesAnalyzed: bytesAnalyzed,
                chunksAnalyzed: chunksAnalyzed,
                routineID: routineID
            )
            : nil

        progress(
            RedTeamProgress(
                phase: paused ? "Pausado" : "Concluído",
                detail: paused
                    ? (pauseReason ?? "O Red Teaming pausou para proteger a memória do Mac.")
                    : "\(uniqueFindings.count) achado(s) no código.",
                fraction: 1,
                availableMemoryBytes: PestMemoryGuard.snapshot().availableBytes,
                budgetBytes: budget.maxRSSGrowthBytes
            )
        )

        return RedTeamReport(
            projectPath: project.path,
            projectName: project.name,
            startedAt: startedAt,
            finishedAt: Date(),
            summary: finalSummary,
            findings: uniqueFindings,
            filesAnalyzed: filesAnalyzed,
            bytesAnalyzed: bytesAnalyzed,
            chunksAnalyzed: chunksAnalyzed,
            limitations: Self.unique(limitations),
            llmUsed: true,
            paused: paused,
            pauseReason: pauseReason,
            resumeState: resumeState,
            memoryBudgetBytes: Int(budget.maxRSSGrowthBytes),
            availableMemoryAtStart: Int(startSnapshot.availableBytes)
        )
    }

    private static func chunk(_ files: [RedTeamFileRef], maxBytes: Int) -> [[RedTeamFileRef]] {
        var chunks: [[RedTeamFileRef]] = []
        var current: [RedTeamFileRef] = []
        var currentBytes = 0

        for file in files {
            let cost = file.bytes + file.path.count + 80
            if !current.isEmpty && currentBytes + cost > maxBytes {
                chunks.append(current)
                current = []
                currentBytes = 0
            }
            current.append(file)
            currentBytes += cost
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    private static func deduplicated(_ findings: [RedTeamFinding]) -> [RedTeamFinding] {
        var seen = Set<String>()
        var unique: [RedTeamFinding] = []
        for finding in findings {
            let key = "\(finding.file.lowercased())|\(finding.line ?? 0)|\(finding.title.lowercased())"
            guard seen.insert(key).inserted else { continue }
            unique.append(finding)
        }
        return unique.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            if lhs.file != rhs.file {
                return lhs.file.localizedStandardCompare(rhs.file) == .orderedAscending
            }
            return (lhs.line ?? 0) < (rhs.line ?? 0)
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}
