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
        llmUsed: Bool = true
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
    }

    public var risk: RiskLevel {
        findings.map(\.severity).max() ?? .unknown
    }
}

public struct RedTeamProgress: Sendable {
    public var phase: String
    public var detail: String
    public var fraction: Double

    public init(phase: String, detail: String, fraction: Double) {
        self.phase = phase
        self.detail = detail
        self.fraction = fraction
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

public enum RedTeamError: Error, LocalizedError {
    case projectNotFound
    case noFiles
    case analysisFailed(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "A pasta do projeto não existe mais."
        case .noFiles:
            return "Nenhum arquivo de código legível foi encontrado neste projeto."
        case .analysisFailed(let detail):
            return detail
        }
    }
}

public struct RedTeamCollector: Sendable {
    public var maxFiles: Int
    public var maxFileBytes: Int
    public var maxTotalBytes: Int
    public var maxDepth: Int

    public init(
        maxFiles: Int = 120,
        maxFileBytes: Int = 60_000,
        maxTotalBytes: Int = 600_000,
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

    public func collect(projectPath: String) throws -> RedTeamCollection {
        let root = URL(fileURLWithPath: projectPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RedTeamError.projectNotFound
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ]
        var files: [RedTeamSourceFile] = []
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

            guard let data = try? Data(contentsOf: url),
                  !data.contains(0),
                  let text = String(data: data, encoding: .utf8) else {
                skipped += 1
                continue
            }

            let relative = relativePath(of: url, root: root)
            let redacted = Self.redact(text)
            files.append(
                RedTeamSourceFile(
                    path: relative,
                    content: redacted,
                    bytes: data.count
                )
            )
            totalBytes += data.count
        }

        let redactedCount = files.filter { $0.content.contains("[REDACTED]") }.count
        if redactedCount > 0 {
            warnings.append("Valores com aparência de segredo foram redigidos em \(redactedCount) arquivo(s).")
        }
        if skipped > 0 {
            warnings.append("\(skipped) arquivo(s) sensível(is), binário(s) ou grande(s) ficaram fora da análise.")
        }

        return RedTeamCollection(
            files: files,
            warnings: warnings,
            skippedFiles: skipped,
            totalBytes: totalBytes
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
    private let llmClient: LLMClient
    private let maxChunkCharacters: Int

    public init(
        collector: RedTeamCollector = RedTeamCollector(),
        llmClient: LLMClient = LLMClient(),
        maxChunkCharacters: Int = 70_000
    ) {
        self.collector = collector
        self.llmClient = llmClient
        self.maxChunkCharacters = maxChunkCharacters
    }

    public func analyze(
        project: ProjectRef,
        progress: @escaping @Sendable (RedTeamProgress) -> Void
    ) async throws -> RedTeamReport {
        let startedAt = Date()
        progress(
            RedTeamProgress(
                phase: "Lendo arquivos",
                detail: "Selecionando código e ignorando segredos e binários…",
                fraction: 0.04
            )
        )

        let collection = try collector.collect(projectPath: project.path)
        guard !collection.files.isEmpty else {
            throw RedTeamError.noFiles
        }

        let chunks = chunk(collection.files)
        var findings: [RedTeamFinding] = []
        var summaries: [String] = []
        var limitations = collection.warnings
        limitations.append(
            "A análise cobre apenas arquivos de texto enviados; binários, dependências instaladas, lockfiles e arquivos grandes ficaram de fora."
        )

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            let fraction = 0.10 + (Double(index) / Double(max(chunks.count, 1))) * 0.78
            progress(
                RedTeamProgress(
                    phase: "Analisando bloco \(index + 1) de \(chunks.count)",
                    detail: "\(chunk.count) arquivo(s) neste bloco. Isso pode levar alguns minutos.",
                    fraction: fraction
                )
            )
            let result = try await llmClient.analyzeRedTeam(
                project: project,
                files: chunk,
                chunkIndex: index + 1,
                chunkCount: chunks.count
            )
            findings.append(contentsOf: result.findings)
            if !result.summary.isEmpty {
                summaries.append(result.summary)
            }
            limitations.append(contentsOf: result.limitations)
        }

        progress(
            RedTeamProgress(
                phase: "Consolidando",
                detail: "Removendo duplicatas e ordenando os achados…",
                fraction: 0.94
            )
        )

        let uniqueFindings = deduplicated(findings)
        let summary = summaries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let finalSummary = summary.isEmpty
            ? "A análise não encontrou falhas de segurança no código enviado."
            : String(summary.prefix(2_400))

        if chunks.count > 1 {
            limitations.append("O projeto foi dividido em \(chunks.count) blocos para caber no contexto da LLM.")
        }

        progress(
            RedTeamProgress(
                phase: "Concluído",
                detail: "\(uniqueFindings.count) achado(s) no código.",
                fraction: 1
            )
        )

        return RedTeamReport(
            projectPath: project.path,
            projectName: project.name,
            startedAt: startedAt,
            finishedAt: Date(),
            summary: finalSummary,
            findings: uniqueFindings,
            filesAnalyzed: collection.files.count,
            bytesAnalyzed: collection.totalBytes,
            chunksAnalyzed: chunks.count,
            limitations: Array(Set(limitations)).sorted()
        )
    }

    private func chunk(_ files: [RedTeamSourceFile]) -> [[RedTeamSourceFile]] {
        var chunks: [[RedTeamSourceFile]] = []
        var current: [RedTeamSourceFile] = []
        var currentCharacters = 0

        for file in files {
            let cost = file.content.count + file.path.count + 80
            if !current.isEmpty && currentCharacters + cost > maxChunkCharacters {
                chunks.append(current)
                current = []
                currentCharacters = 0
            }
            current.append(file)
            currentCharacters += cost
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    private func deduplicated(_ findings: [RedTeamFinding]) -> [RedTeamFinding] {
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
}
