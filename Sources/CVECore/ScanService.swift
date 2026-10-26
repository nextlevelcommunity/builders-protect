import Foundation

public final class ScanService: @unchecked Sendable {
    private let scanner: ProjectScanner
    private let cveClient: CVEMCPClient
    private let llmClient: LLMClient
    private let settingsStore: SettingsStore

    public init(
        scanner: ProjectScanner = ProjectScanner(),
        cveClient: CVEMCPClient = CVEMCPClient(),
        llmClient: LLMClient = LLMClient(),
        settingsStore: SettingsStore = .shared
    ) {
        self.scanner = scanner
        self.cveClient = cveClient
        self.llmClient = llmClient
        self.settingsStore = settingsStore
    }

    public func scan(
        folders: [MonitoredFolder],
        excludedPaths: [String] = [],
        progress: @escaping @Sendable (ScanProgress) -> Void = { _ in }
    ) async throws -> ScanReport {
        let startedAt = Date()
        let uniqueFolders = deduplicated(folders)

        progress(ScanProgress(phase: "Descobrindo projetos", detail: "Lendo as pastas monitoradas…", fraction: 0.02))
        let discovery = scanner.scan(folders: uniqueFolders, excludedPaths: excludedPaths)
        try Task.checkCancellation()

        var warnings = discovery.warnings
        let projects = discovery.projects

        if projects.isEmpty {
            progress(ScanProgress(phase: "Concluído", detail: "Nenhum projeto encontrado", fraction: 1))
            return emptyReport(
                folders: uniqueFolders,
                projectsScanned: 0,
                startedAt: startedAt,
                warnings: warnings
            )
        }

        progress(
            ScanProgress(
                phase: "Lendo manifestos",
                detail: "\(quantity(projects.count, "projeto", "projetos")) encontrados",
                fraction: 0.08
            )
        )

        var coordinateProjects: [CoordinateKey: Set<String>] = [:]
        var coordinateLockfile: [CoordinateKey: String] = [:]
        var rawJobs: [(projectPath: String, payload: LockfilePayload)] = []

        for project in projects {
            for payload in project.payloads {
                if !payload.packages.isEmpty {
                    for package in payload.packages {
                        let key = CoordinateKey(
                            ecosystem: package.ecosystem,
                            name: package.name,
                            version: package.version
                        )
                        coordinateProjects[key, default: []].insert(project.ref.path)
                        if coordinateLockfile[key] == nil {
                            coordinateLockfile[key] = payload.name
                        }
                    }
                } else if let content = payload.content, !content.isEmpty {
                    rawJobs.append((project.ref.path, payload))
                }
            }
        }

        let uniqueCoordinates = Array(coordinateProjects.keys)
        let batches = uniqueCoordinates.chunked(into: 120)
        let batchWeight = batches.isEmpty ? 0 : 0.33 / Double(batches.count)

        var matchesByProject: [String: [CVEMatch]] = [:]
        var lockfileLookup: [String: String] = [:]

        for (index, batch) in batches.enumerated() {
            try Task.checkCancellation()
            let payload = LockfilePayload(
                name: "packages",
                packages: batch.map {
                    PackageCoordinate(
                        ecosystem: $0.ecosystem,
                        name: $0.name,
                        version: $0.version
                    )
                }
            )
            do {
                let matches = try await cveClient.check(payload: payload)
                for match in matches {
                    let key = CoordinateKey(
                        ecosystem: match.ecosystem,
                        name: match.packageName,
                        version: match.installedVersion
                    )
                    guard let projectPaths = coordinateProjects[key] else { continue }
                    for path in projectPaths {
                        matchesByProject[path, default: []].append(match)
                        lockfileLookup[findingKey(projectPath: path, match: match)] =
                            coordinateLockfile[key]
                    }
                }
            } catch {
                warnings.append("Não consegui consultar a base de vulnerabilidades: \(error.localizedDescription)")
                break
            }

            progress(
                ScanProgress(
                    phase: "Cruzando com a base de vulnerabilidades",
                    detail: "Lote \(index + 1) de \(batches.count)",
                    fraction: 0.08 + Double(index + 1) * batchWeight
                )
            )
        }

        if !rawJobs.isEmpty {
            let rawChunks = rawJobs.chunked(into: 3)
            let rawWeight = 0.27 / Double(max(1, rawJobs.count))
            var completed = 0

            for chunk in rawChunks {
                try Task.checkCancellation()
                await withTaskGroup(of: RawCheckOutcome.self) { group in
                    for job in chunk {
                        group.addTask { [cveClient] in
                            do {
                                let matches = try await cveClient.check(payload: job.payload)
                                return RawCheckOutcome(
                                    projectPath: job.projectPath,
                                    lockfile: job.payload.name,
                                    matches: matches,
                                    errorMessage: nil
                                )
                            } catch {
                                return RawCheckOutcome(
                                    projectPath: job.projectPath,
                                    lockfile: job.payload.name,
                                    matches: [],
                                    errorMessage: error.localizedDescription
                                )
                            }
                        }
                    }

                    for await outcome in group {
                        if let message = outcome.errorMessage {
                            warnings.append("Não consegui analisar um lockfile: \(message)")
                        }
                        for match in outcome.matches {
                            matchesByProject[outcome.projectPath, default: []].append(match)
                            lockfileLookup[
                                findingKey(projectPath: outcome.projectPath, match: match)
                            ] = outcome.lockfile
                        }
                        completed += 1
                        let fraction = 0.41 + Double(completed) * rawWeight
                        progress(
                            ScanProgress(
                                phase: "Lendo lockfiles",
                                detail: "\(min(completed, rawJobs.count)) de \(rawJobs.count)",
                                fraction: min(fraction, 0.68)
                            )
                        )
                    }
                }
            }
        }

        let allMatches = matchesByProject.values.flatMap { $0 }
        var uniqueCVEs: [String: CVEMatch] = [:]
        for match in allMatches where uniqueCVEs[match.id] == nil {
            uniqueCVEs[match.id] = match
        }
        let orderedCVEs = uniqueCVEs.values.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return (lhs.cvss ?? 0) > (rhs.cvss ?? 0)
        }
        let selectedCVEs = Array(orderedCVEs.prefix(48))
        var details: [String: CVEDetail] = [:]
        var detailFailures = 0

        if !selectedCVEs.isEmpty {
            let detailChunks = selectedCVEs.chunked(into: 4)
            let detailWeight = 0.16 / Double(selectedCVEs.count)
            var completed = 0

            for chunk in detailChunks {
                try Task.checkCancellation()
                await withTaskGroup(of: (String, CVEDetail?).self) { group in
                    for match in chunk {
                        group.addTask { [cveClient] in
                            let detail = try? await cveClient.vulnerability(id: match.id)
                            return (match.id, detail)
                        }
                    }

                    for await (id, detail) in group {
                        if let detail {
                            details[id] = detail
                        } else {
                            detailFailures += 1
                        }
                        completed += 1
                        let fraction = 0.7 + Double(completed) * detailWeight
                        progress(
                            ScanProgress(
                                phase: "Buscando detalhes",
                                detail: "\(min(completed, selectedCVEs.count)) de \(selectedCVEs.count) vulnerabilidades",
                                fraction: min(fraction, 0.86)
                            )
                        )
                    }
                }
            }
        }

        if detailFailures > 0 {
            warnings.append("Algumas vulnerabilidades não puderam ser detalhadas; os achados principais foram mantidos.")
        }

        var alerts: [ProjectAlert] = []
        for project in projects {
            let matches = matchesByProject[project.ref.path] ?? []
            guard !matches.isEmpty else { continue }

            var seen = Set<String>()
            var findings: [DependencyFinding] = []
            for match in matches {
                let key = findingKey(projectPath: project.ref.path, match: match)
                guard seen.insert(key).inserted else { continue }

                let detail = details[match.id]
                let fixed = detail?.fixedVersion(
                    package: match.packageName,
                    ecosystem: match.ecosystem,
                    installedVersion: match.installedVersion
                )
                let cvss = detail?.cvss ?? match.cvss
                let isKEV = detail?.isKEV ?? false
                let summary = detail?.description.normalizedWhitespace
                findings.append(
                    DependencyFinding(
                        projectPath: project.ref.path,
                        cveID: match.id,
                        title: detail?.title ?? match.title,
                        packageName: match.packageName,
                        installedVersion: match.installedVersion,
                        ecosystem: match.ecosystem,
                        cvss: cvss,
                        severity: RiskLevel.from(cvss: cvss, isKEV: isKEV),
                        url: match.url,
                        summary: summary?.isEmpty == false ? String(summary!.prefix(600)) : nil,
                        fixedVersion: fixed,
                        isKEV: isKEV,
                        referenceURLs: detail?.references ?? [],
                        lockfile: lockfileLookup[key]
                    )
                )
            }

            guard !findings.isEmpty else { continue }
            findings.sort { lhs, rhs in
                if lhs.isKEV != rhs.isKEV { return lhs.isKEV }
                if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
                if (lhs.cvss ?? 0) != (rhs.cvss ?? 0) {
                    return (lhs.cvss ?? 0) > (rhs.cvss ?? 0)
                }
                return lhs.packageName.localizedStandardCompare(rhs.packageName) == .orderedAscending
            }

            let risk = findings.map(\.severity).max() ?? .unknown
            let generatedAt = Date()
            var alert = ProjectAlert(
                project: project.ref,
                findings: findings,
                risk: risk,
                headline: "",
                diagnosis: "",
                recommendation: "",
                fixPrompt: "",
                llmUsed: false,
                generatedAt: generatedAt
            )
            alert.headline = fallbackHeadline(for: alert)
            alert.diagnosis = fallbackDiagnosis(for: alert)
            alert.recommendation = fallbackRecommendation(for: alert)
            alert.fixPrompt = PromptBuilder.build(
                for: alert,
                diagnosis: alert.diagnosis,
                recommendation: alert.recommendation
            )
            alerts.append(alert)
        }

        alerts.sort { lhs, rhs in
            if lhs.risk != rhs.risk { return lhs.risk > rhs.risk }
            return (lhs.highestCVSS ?? 0) > (rhs.highestCVSS ?? 0)
        }

        var llmUsed = false
        var summary = fallbackSummary(for: alerts)
        var nextSteps = fallbackNextSteps(for: alerts)

        if !alerts.isEmpty {
            progress(
                ScanProgress(
                    phase: "Analisando com a Cultura Builder",
                    detail: "Gerando diagnóstico e plano de correção…",
                    fraction: 0.9
                )
            )
            do {
                let diagnosis = try await llmClient.diagnose(alerts: alerts)
                llmUsed = true

                let byPath = Dictionary(
                    uniqueKeysWithValues: diagnosis.projects.map { ($0.projectPath, $0) }
                )
                alerts = alerts.map { alert in
                    var updated = alert
                    if let projectDiagnosis = byPath[alert.project.path] {
                        if !projectDiagnosis.headline.isEmpty {
                            updated.headline = projectDiagnosis.headline
                        }
                        if !projectDiagnosis.diagnosis.isEmpty {
                            updated.diagnosis = projectDiagnosis.diagnosis
                        }
                        if !projectDiagnosis.recommendation.isEmpty {
                            updated.recommendation = projectDiagnosis.recommendation
                        }
                        updated.llmUsed = true
                        updated.fixPrompt = PromptBuilder.build(
                            for: updated,
                            diagnosis: updated.diagnosis,
                            recommendation: updated.recommendation,
                            llmPlan: projectDiagnosis.fixPrompt
                        )
                    } else {
                        updated.fixPrompt = PromptBuilder.build(
                            for: updated,
                            diagnosis: updated.diagnosis,
                            recommendation: updated.recommendation
                        )
                    }
                    return updated
                }

                if !diagnosis.summary.isEmpty {
                    summary = diagnosis.summary
                }
                if !diagnosis.nextSteps.isEmpty {
                    nextSteps = diagnosis.nextSteps
                }
            } catch {
                warnings.append("A análise da IA não pôde ser concluída: \(error.localizedDescription)")
            }
        }

        progress(
            ScanProgress(
                phase: "Concluído",
                detail: "\(quantity(alerts.count, "projeto", "projetos")) com achados",
                fraction: 1
            )
        )

        let finishedAt = Date()
        let report = ScanReport(
            startedAt: startedAt,
            finishedAt: finishedAt,
            folders: uniqueFolders.map(\.path),
            projectsScanned: projects.count,
            lockfilesChecked: projects.reduce(0) { $0 + $1.payloads.count },
            alerts: alerts,
            summary: summary,
            nextSteps: nextSteps,
            llmUsed: llmUsed,
            warnings: deduplicatedStrings(warnings)
        )
        return report
    }

    private func emptyReport(
        folders: [MonitoredFolder],
        projectsScanned: Int,
        startedAt: Date,
        warnings: [String]
    ) -> ScanReport {
        return ScanReport(
            startedAt: startedAt,
            finishedAt: Date(),
            folders: folders.map(\.path),
            projectsScanned: projectsScanned,
            lockfilesChecked: 0,
            alerts: [],
            summary: "Nenhum projeto com lockfile foi encontrado nas pastas monitoradas.",
            nextSteps: [
                "Adicione uma pasta que contenha projetos Node, Python, Rust, Go, Ruby, Elixir ou Nix.",
                "Mantenha a rotina diária ativa para acompanhar novas vulnerabilidades.",
                "Rode uma nova varredura depois de ajustar as pastas."
            ],
            llmUsed: false,
            warnings: deduplicatedStrings(warnings)
        )
    }

    private func fallbackHeadline(for alert: ProjectAlert) -> String {
        if alert.hasKEV {
            return "Vulnerabilidades com exploração ativa em \(quantity(alert.packageCount, "pacote", "pacotes"))"
        }
        if alert.risk == .critical {
            return "Falhas críticas em \(quantity(alert.packageCount, "pacote", "pacotes"))"
        }
        if alert.risk == .high {
            return "Vulnerabilidades de risco alto"
        }
        return "Vulnerabilidades em \(quantity(alert.packageCount, "pacote", "pacotes"))"
    }

    private func fallbackDiagnosis(for alert: ProjectAlert) -> String {
        let top = alert.packageAggregates.prefix(3).map { package in
            "\(package.name)@\(package.installedVersion)"
        }
        var text = "A base de vulnerabilidades confirmou falhas em \(quantity(alert.packageCount, "pacote", "pacotes")) deste projeto."
        if alert.hasKEV {
            text += " Há falhas na lista KEV, com exploração ativa conhecida, e elas devem ser tratadas primeiro."
        }
        if !top.isEmpty {
            text += " A maior exposição está em \(top.joined(separator: ", "))."
            text += " Atualizar esses pacotes reduz a superfície de ataque sem mexer no restante da aplicação."
        }
        return text
    }

    private func fallbackRecommendation(for alert: ProjectAlert) -> String {
        let fixes = alert.packageAggregates.compactMap { package -> String? in
            guard let fixed = package.fixedVersion else { return nil }
            return "\(package.name) para \(fixed) ou superior"
        }
        if !fixes.isEmpty {
            return "Atualize \(fixes.prefix(4).joined(separator: ", ")), regenere o lockfile e rode a auditoria e os testes do projeto."
        }
        return "Atualize os pacotes afetados para a última versão corrigida compatível, regenere o lockfile e rode a auditoria e os testes do projeto."
    }

    private func fallbackSummary(for alerts: [ProjectAlert]) -> String {
        guard !alerts.isEmpty else {
            return "Nenhuma vulnerabilidade conhecida encontrada nos projetos monitorados."
        }
        return "Vulnerabilidades encontradas em \(quantity(alerts.count, "projeto", "projetos")), com prioridade para os riscos críticos e altos."
    }

    private func fallbackNextSteps(for alerts: [ProjectAlert]) -> [String] {
        guard !alerts.isEmpty else {
            return [
                "Manter a rotina diária ativa.",
                "Adicionar outra pasta de projetos.",
                "Revisar os alertas depois da próxima varredura."
            ]
        }
        var steps = alerts.prefix(3).map { alert in
            "Atualizar \(alert.project.name): \(alert.recommendation)"
        }
        steps.append("Copiar o prompt de correção e aplicar com seu agente de código.")
        steps.append("Rodar os testes e uma nova varredura para confirmar.")
        return Array(steps.prefix(5))
    }

    private func deduplicated(_ folders: [MonitoredFolder]) -> [MonitoredFolder] {
        var seen = Set<String>()
        var result: [MonitoredFolder] = []
        for folder in folders {
            let path = URL(fileURLWithPath: folder.path).standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            result.append(folder)
        }
        return result
    }

    private func quantity(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }

    private func deduplicatedStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where !value.isEmpty {
            guard seen.insert(value).inserted else { continue }
            result.append(value)
        }
        return result
    }
}

private struct CoordinateKey: Hashable {
    var ecosystem: String
    var name: String
    var version: String
}

private struct RawCheckOutcome: Sendable {
    var projectPath: String
    var lockfile: String
    var matches: [CVEMatch]
    var errorMessage: String?
}

private func findingKey(projectPath: String, match: CVEMatch) -> String {
    "\(projectPath)|\(match.id)|\(match.packageName)|\(match.installedVersion)"
}

private extension Collection {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [Array(self)] }
        var result: [[Element]] = []
        var current: [Element] = []
        current.reserveCapacity(size)
        for element in self {
            current.append(element)
            if current.count == size {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

private extension String {
    var normalizedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

