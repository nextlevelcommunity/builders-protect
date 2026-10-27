import Foundation

public final class PestService: @unchecked Sendable {
    private let knowledge: PestKnowledgeBase
    private let llmClient: LLMClient
    private let analyzer: PestStaticAnalyzer

    public init(
        knowledge: PestKnowledgeBase = .shared,
        llmClient: LLMClient = LLMClient(),
        analyzer: PestStaticAnalyzer = PestStaticAnalyzer()
    ) {
        self.knowledge = knowledge
        self.llmClient = llmClient
        self.analyzer = analyzer
    }

    public func analyze(
        project: ProjectRef,
        useLLM: Bool,
        routineID: UUID? = nil,
        resume: PestResumeState? = nil,
        progress: @escaping @Sendable (PestProgress) -> Void
    ) async throws -> PestReport {
        let startedAt = resume?.startedAt ?? Date()
        let startSnapshot = PestMemoryGuard.snapshot()
        if startSnapshot.availableBytes < PestMemoryGuard.minimumAvailableBytes {
            throw PestError.insufficientMemory(
                "O Mac tem \(PestMemoryGuard.formatBytes(startSnapshot.availableBytes)) de memória disponível. Feche apps pesados e tente de novo; o mínimo seguro para o Pest é \(PestMemoryGuard.formatBytes(PestMemoryGuard.minimumAvailableBytes))."
            )
        }
        if let disk = startSnapshot.diskAvailableBytes,
           disk < PestMemoryGuard.minimumDiskBytes {
            throw PestError.insufficientDisk(
                "O disco tem \(PestMemoryGuard.formatBytes(UInt64(max(disk, 0)))) livres. Libere pelo menos \(PestMemoryGuard.formatBytes(UInt64(PestMemoryGuard.minimumDiskBytes))) para o Pest montar o relatório."
            )
        }
        guard let budget = PestMemoryGuard.budget(for: startSnapshot) else {
            throw PestError.insufficientMemory(
                "O Pest não conseguiu reservar um orçamento seguro de memória. Feche apps pesados e tente de novo."
            )
        }

        let collector = PestCollector(
            maxFiles: budget.maxFiles,
            maxFileBytes: budget.maxFileBytes,
            maxTotalBytes: budget.maxTotalBytes
        )
        let reader = PestReader()

        progress(
            PestProgress(
                phase: "Mapeando",
                detail: "Lendo a estrutura do projeto com orçamento de \(PestMemoryGuard.formatBytes(UInt64(budget.maxTotalBytes))).",
                fraction: 0.02,
                availableMemoryBytes: startSnapshot.availableBytes,
                budgetBytes: budget.maxRSSGrowthBytes
            )
        )

        let inventory = try collector.inventory(projectPath: project.path)
        guard !inventory.files.isEmpty else {
            throw PestError.noFiles
        }

        let checks = knowledge.selectChecks(
            project: project,
            filePaths: inventory.files.map(\.path),
            limit: 20
        )
        guard !checks.isEmpty else {
            throw PestError.analysisFailed("Nenhum check compatível com este projeto foi encontrado.")
        }
        let llmChecks = Array(checks.prefix(12))

        var findings = resume?.findings ?? []
        var summaryParts = resume?.summaryParts ?? []
        var limitations = resume?.limitations ?? []
        limitations.append(contentsOf: inventory.warnings)
        limitations.append(
            "Análise estática guiada pelo catálogo Pest/Nuclei: o app não executa o projeto, não instala dependências e não envia requisições ao alvo."
        )
        limitations.append(
            "Limites desta execução: até \(budget.maxFiles) arquivos, \(PestMemoryGuard.formatBytes(UInt64(budget.maxTotalBytes))) de código e \(PestMemoryGuard.formatBytes(budget.maxRSSGrowthBytes)) de memória adicional."
        )

        let processed = Set(resume?.processedPaths ?? [])
        let remaining = inventory.files.filter { !processed.contains($0.path) }
        let chunks = collector.chunks(
            of: remaining,
            maxCharacters: budget.maxChunkCharacters
        )
        let totalChunks = chunks.count
        var processedPaths = resume?.processedPaths ?? []
        var filesAnalyzed = resume?.filesAnalyzed ?? 0
        var bytesAnalyzed = resume?.bytesAnalyzed ?? 0
        var chunksAnalyzed = resume?.chunksAnalyzed ?? 0
        var llmUsed = resume?.llmUsed ?? false
        var llmAllowed = useLLM
        var llmChunks = 0
        var paused = false
        var pauseReason: String? = nil

        if remaining.isEmpty {
            summaryParts.append("O Pest já havia processado todos os arquivos do orçamento.")
        }

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            if let reason = PestMemoryGuard.pauseReason(
                baselineRSS: startSnapshot.residentBytes,
                budget: budget
            ) {
                let snapshot = PestMemoryGuard.snapshot()
                let canRecover = snapshot.availableBytes < budget.minimumAvailableBytes
                if canRecover,
                   let recovered = await waitForMemory(
                       since: startSnapshot,
                       budget: budget,
                       fraction: fraction(index, of: totalChunks),
                       progress: progress
                   ) {
                    pauseReason = recovered
                    paused = true
                    break
                }
                if !canRecover {
                    pauseReason = reason
                    paused = true
                    break
                }
            }

            let chunkFraction = fraction(index, of: totalChunks)
            progress(
                PestProgress(
                    phase: "Analisando",
                    detail: "Bloco \(index + 1) de \(totalChunks) · \(chunk.count) arquivo(s).",
                    fraction: chunkFraction,
                    availableMemoryBytes: PestMemoryGuard.snapshot().availableBytes,
                    budgetBytes: budget.maxRSSGrowthBytes
                )
            )

            var sources: [PestSourceFile] = []
            for ref in chunk {
                do {
                    if let source = try reader.read(
                        ref,
                        projectPath: project.path,
                        maxBytes: budget.maxFileBytes
                    ) {
                        sources.append(source)
                    }
                } catch {
                    limitations.append(
                        "Não consegui ler \(ref.path): \(error.localizedDescription)"
                    )
                }
            }
            guard !sources.isEmpty else { continue }

            findings.append(
                contentsOf: analyzer.analyze(
                    files: sources,
                    checks: checks,
                    project: project
                )
            )

            if llmAllowed, llmChunks < budget.maxLLMChunks {
                progress(
                    PestProgress(
                        phase: "Consultando IA",
                        detail: "Bloco \(index + 1) de \(totalChunks) · revisão semântica do código.",
                        fraction: min(0.94, chunkFraction + 0.02),
                        availableMemoryBytes: PestMemoryGuard.snapshot().availableBytes,
                        budgetBytes: budget.maxRSSGrowthBytes
                    )
                )
                do {
                    let result = try await llmClient.analyzePest(
                        project: project,
                        checks: llmChecks,
                        files: sources,
                        chunkIndex: index + 1,
                        chunkCount: totalChunks
                    )
                    findings.append(contentsOf: result.findings)
                    if !result.summary.isEmpty {
                        summaryParts.append(result.summary)
                    }
                    limitations.append(contentsOf: result.limitations)
                    llmUsed = true
                    llmChunks += 1
                } catch is CancellationError {
                    throw CancellationError()
                } catch let error as LLMError {
                    limitations.append(
                        "A IA não concluiu o bloco \(index + 1): \(error.localizedDescription)"
                    )
                    if case .authUnavailable = error {
                        llmAllowed = false
                    }
                } catch {
                    limitations.append(
                        "A IA não concluiu o bloco \(index + 1): \(error.localizedDescription)"
                    )
                }
            }

            processedPaths.append(contentsOf: chunk.map(\.path))
            filesAnalyzed += sources.count
            bytesAnalyzed += sources.reduce(0) { $0 + $1.bytes }
            chunksAnalyzed += 1

            if let reason = PestMemoryGuard.pauseReason(
                baselineRSS: startSnapshot.residentBytes,
                budget: budget
            ) {
                paused = true
                pauseReason = reason
                break
            }
        }

        let uniqueFindings = Self.dedupe(findings)
        let summary = Self.makeSummary(
            project: project,
            findings: uniqueFindings,
            parts: summaryParts,
            paused: paused
        )
        let resumeState = paused
            ? PestResumeState(
                startedAt: startedAt,
                processedPaths: processedPaths,
                findings: uniqueFindings,
                summaryParts: summaryParts,
                limitations: Self.unique(limitations),
                checksApplied: checks.map(\.id),
                filesAnalyzed: filesAnalyzed,
                bytesAnalyzed: bytesAnalyzed,
                chunksAnalyzed: chunksAnalyzed,
                llmUsed: llmUsed,
                routineID: routineID
            )
            : nil

        progress(
            PestProgress(
                phase: paused ? "Pausado" : "Concluído",
                detail: paused
                    ? (pauseReason ?? "O Pest pausou para proteger a memória do Mac.")
                    : "\(uniqueFindings.count) achado(s) em \(filesAnalyzed) arquivo(s).",
                fraction: 1,
                availableMemoryBytes: PestMemoryGuard.snapshot().availableBytes,
                budgetBytes: budget.maxRSSGrowthBytes
            )
        )

        return PestReport(
            projectPath: project.path,
            projectName: project.name,
            startedAt: startedAt,
            finishedAt: Date(),
            summary: summary,
            findings: uniqueFindings,
            filesAnalyzed: filesAnalyzed,
            bytesAnalyzed: bytesAnalyzed,
            chunksAnalyzed: chunksAnalyzed,
            checksApplied: checks.map(\.id),
            limitations: Self.unique(limitations),
            llmUsed: llmUsed,
            paused: paused,
            pauseReason: pauseReason,
            resumeState: resumeState,
            memoryBudgetBytes: budget.maxRSSGrowthBytes,
            availableMemoryAtStart: startSnapshot.availableBytes,
            diskAvailableAtStart: startSnapshot.diskAvailableBytes
        )
    }

    private func waitForMemory(
        since start: PestMemorySnapshot,
        budget: PestResourceBudget,
        fraction value: Double,
        progress: @escaping @Sendable (PestProgress) -> Void
    ) async -> String? {
        var waited: TimeInterval = 0
        while let reason = PestMemoryGuard.pauseReason(
            baselineRSS: start.residentBytes,
            budget: budget
        ) {
            let snapshot = PestMemoryGuard.snapshot()
            progress(
                PestProgress(
                    phase: "Aguardando memória",
                    detail: "\(reason) Feche apps pesados ou libere espaço; o Pest tenta retomar por até 90 segundos.",
                    fraction: value,
                    availableMemoryBytes: snapshot.availableBytes,
                    budgetBytes: budget.maxRSSGrowthBytes
                )
            )
            if snapshot.availableBytes >= budget.minimumAvailableBytes {
                return reason
            }
            if waited >= 90 { return reason }
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return reason
            }
            waited += 5
        }
        return nil
    }

    private func fraction(_ index: Int, of total: Int) -> Double {
        guard total > 0 else { return 0.05 }
        return min(0.95, 0.05 + (Double(index) / Double(total)) * 0.9)
    }

    private static func dedupe(_ findings: [PestFinding]) -> [PestFinding] {
        var byKey: [String: PestFinding] = [:]
        var order: [String] = []
        for finding in findings {
            let key = [
                finding.checkID,
                finding.file,
                finding.line.map(String.init) ?? "",
                finding.evidence
            ].joined(separator: "|")
            if let existing = byKey[key] {
                let preferred = finding.source == .ia && existing.source != .ia
                    ? finding
                    : (existing.source == .ia && finding.source != .ia ? existing : finding)
                let chosen = preferred.fixPrompt.count >= existing.fixPrompt.count
                    ? preferred
                    : existing
                byKey[key] = chosen
            } else {
                byKey[key] = finding
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }
            .sorted { lhs, rhs in
                if lhs.severity != rhs.severity {
                    return lhs.severity > rhs.severity
                }
                if lhs.file != rhs.file {
                    return lhs.file < rhs.file
                }
                return (lhs.line ?? 0) < (rhs.line ?? 0)
            }
    }

    private static func makeSummary(
        project: ProjectRef,
        findings: [PestFinding],
        parts: [String],
        paused: Bool
    ) -> String {
        let uniqueParts = unique(parts)
        if !uniqueParts.isEmpty {
            return String(uniqueParts.joined(separator: " ").prefix(2_400))
        }
        if findings.isEmpty {
            return paused
                ? "O Pest pausou antes de concluir. Nenhum achado confirmado nos blocos já analisados."
                : "O Pest não confirmou brechas nos arquivos analisados de \(project.name). Isso não prova que o projeto é seguro; veja as limitações."
        }
        let critical = findings.filter { $0.severity == .critical }.count
        let high = findings.filter { $0.severity == .high }.count
        return "O Pest revisou \(project.name) e encontrou \(findings.count) achado(s), com \(critical) crítico(s) e \(high) alto(s). Priorize os itens com prompt de correção antes de publicar."
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
