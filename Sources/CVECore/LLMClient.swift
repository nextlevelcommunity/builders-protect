import Foundation

public struct LLMProjectDiagnosis: Sendable {
    public var projectPath: String
    public var risk: RiskLevel?
    public var headline: String
    public var diagnosis: String
    public var recommendation: String
    public var fixPrompt: String

    public init(
        projectPath: String,
        risk: RiskLevel?,
        headline: String,
        diagnosis: String,
        recommendation: String,
        fixPrompt: String
    ) {
        self.projectPath = projectPath
        self.risk = risk
        self.headline = headline
        self.diagnosis = diagnosis
        self.recommendation = recommendation
        self.fixPrompt = fixPrompt
    }
}

public struct LLMDiagnosis: Sendable {
    public var headline: String
    public var summary: String
    public var nextSteps: [String]
    public var projects: [LLMProjectDiagnosis]

    public init(
        headline: String,
        summary: String,
        nextSteps: [String],
        projects: [LLMProjectDiagnosis]
    ) {
        self.headline = headline
        self.summary = summary
        self.nextSteps = nextSteps
        self.projects = projects
    }
}

public enum LLMError: Error, LocalizedError {
    case authUnavailable(String)
    case requestFailed(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .authUnavailable(let detail): return detail
        case .requestFailed(let detail): return detail
        case .invalidResponse(let detail): return detail
        }
    }
}

public final class LLMClient: @unchecked Sendable {
    private let authStore: BuilderAuthStore
    private let session: URLSession
    private let settingsProvider: @Sendable () -> AppSettings

    public init(
        authStore: BuilderAuthStore = .shared,
        session: URLSession = .shared,
        settingsProvider: @escaping @Sendable () -> AppSettings = { SettingsStore.shared.loadSettings() }
    ) {
        self.authStore = authStore
        self.session = session
        self.settingsProvider = settingsProvider
    }

    private var outputLanguage: String {
        settingsProvider().appLanguage.isPortuguese ? "português do Brasil" : "English"
    }

    public func diagnose(alerts: [ProjectAlert]) async throws -> LLMDiagnosis {
        let configuration = try await resolveConfiguration()
        let language = outputLanguage

        let payload = try makePayload(alerts: alerts)
        let system = """
        Você é o analista de segurança do Builders Protect, um app de menu bar da Cultura Builder para macOS.
        Receba achados reais da base de vulnerabilidades e produza um diagnóstico técnico para o desenvolvedor corrigir os projetos.

        Regras obrigatórias:
        - Responda SOMENTE com um objeto JSON válido, sem markdown, sem comentários e sem cercas de código.
        - Use exclusivamente os dados fornecidos. Nunca invente identificador de vulnerabilidade, pacote, versão, caminho ou comando.
        - Não invente uma versão corrigida quando o campo estiver ausente; diga "atualizar para a última versão corrigida compatível".
        - Não cite cve.now e não inclua contagens de vulnerabilidades nos headlines; descreva o risco e os pacotes afetados.
        - Trate KEV como prioridade máxima, seguido de CVSS alto e dependências de produção.
        - Seja específico, direto e escreva em \(language).
        - Não produza análise passo a passo; vá direto ao objeto JSON.
        - Cada item de projects deve usar exatamente um dos caminhos fornecidos em projetos[].caminho.
        - diagnosis deve explicar o risco real e o que priorizar.
        - recommendation deve dizer o que atualizar e o que validar depois.
        - fix_prompt deve ser um prompt completo, pronto para colar em um agente de código (Claude Code, Codex, Cursor). Inclua o caminho exato do projeto, pacotes e versões, identificadores de vulnerabilidade, comandos prováveis, testes e critérios de conclusão. Não use cercas de markdown.
        - Não inclua segredos, tokens, arquivos .env ou instruções destrutivas.

        Formato exato:
        {"headline":"frase curta","summary":"resumo do cenário","next_steps":["passo 1","passo 2"],"projects":[{"path":"/caminho/exato","risk":"critical|high|medium|low","headline":"frase curta do projeto","diagnosis":"análise específica","recommendation":"o que atualizar e validar","fix_prompt":"prompt completo para o agente de código"}]}
        """

        let user = """
        Analise estes projetos e produza o diagnóstico. Priorize o que reduz risco real mais rápido.
        \(payload)
        """

        let content = try await complete(system: system, user: user, configuration: configuration)
        return try parseDiagnosis(content, alerts: alerts)
    }

    public func analyzeRedTeam(
        project: ProjectRef,
        files: [RedTeamSourceFile],
        chunkIndex: Int,
        chunkCount: Int
    ) async throws -> RedTeamLLMResult {
        let configuration = try await resolveConfiguration()
        let language = outputLanguage

        let payload = try makeRedTeamPayload(
            project: project,
            files: files,
            chunkIndex: chunkIndex,
            chunkCount: chunkCount
        )
        let system = """
        Você é um especialista sênior em red teaming de aplicações, contratado pela Cultura Builder para revisar código de projetos locais.
        Analise SOMENTE os arquivos fornecidos e procure falhas de segurança reais no código, não dependências desatualizadas.

        Prioridades:
        - Bypass de autenticação e autorização, IDOR, escalada de privilégio.
        - Injection (SQL, comando, template, header, log), SSRF, path traversal, upload inseguro.
        - XSS, CSRF, CORS permissivo, exposição de dados, criptografia fraca.
        - Segredos embutidos, validação insuficiente, race conditions e configuração insegura.
        - Qualquer caminho em que dados externos cheguem a uma operação perigosa sem validação.

        Regras obrigatórias:
        - Responda SOMENTE com um objeto JSON válido, sem markdown, sem comentários e sem cercas de código.
        - Use apenas evidências presentes nos arquivos. Nunca invente arquivo, linha, trecho ou falha.
        - Se a evidência for indireta, use confidence "baixa" e explique a limitação no campo impact.
        - Cite o caminho relativo exato e uma linha aproximada. O campo evidence deve ter um trecho curto e literal.
        - Não reporte dependências desatualizadas, CVEs de pacotes ou problemas já cobertos pela análise de lockfiles.
        - Não inclua segredos, tokens ou valores sensíveis na resposta.
        - Máximo de 15 achados, priorizando os de maior impacto e maior confiança.
        - Escreva em \(language), de forma direta e técnica.
        - Se não houver achados, devolva findings vazio e um summary explicando o que foi revisado.

        Formato exato:
        {"summary":"resumo do que foi revisado e do risco geral","findings":[{"severity":"critical|high|medium|low","title":"falha curta","file":"caminho/relativo.ext","line":123,"evidence":"trecho literal curto","impact":"o que um atacante consegue fazer","recommendation":"correção concreta","confidence":"alta|media|baixa"}],"limitations":["limite da análise"]}
        """

        let user = """
        Projeto: \(project.name)
        Caminho: \(project.path)
        Bloco \(chunkIndex) de \(chunkCount).

        Analise os arquivos abaixo e produza o relatório de red teaming.
        \(payload)
        """

        let content = try await completeRedTeam(system: system, user: user, configuration: configuration)
        return try parseRedTeam(content)
    }

    public func analyzePest(
        project: ProjectRef,
        checks: [PestCheck],
        files: [PestSourceFile],
        chunkIndex: Int,
        chunkCount: Int
    ) async throws -> PestLLMResult {
        let configuration = try await resolveConfiguration()
        let language = outputLanguage

        let payload = try makePestPayload(
            project: project,
            checks: checks,
            files: files,
            chunkIndex: chunkIndex,
            chunkCount: chunkCount
        )
        let system = """
        Você é o Pest, revisor sênior de segurança de aplicações do Builders Protect, da Cultura Builder.
        O checklist abaixo foi destilado do catálogo de templates do ProjectDiscovery Nuclei. Use-o como guia, não como prova.
        Analise SOMENTE os arquivos fornecidos e procure brechas reais, oportunidades de hardening e configurações perigosas.

        Prioridades:
        - Bypass de autenticação e autorização, IDOR, escalada de privilégio, tenant isolation.
        - Injection (SQL, comando, template, header, desserialização), SSRF, path traversal, upload inseguro.
        - XSS, CSRF, CORS permissivo, exposição de dados, criptografia fraca, JWT inseguro.
        - Segredos embutidos, validação insuficiente, race conditions e configuração insegura.
        - Qualquer caminho em que dados externos cheguem a uma operação perigosa sem validação.

        Regras obrigatórias:
        - Responda SOMENTE com um objeto JSON válido, sem markdown, sem comentários e sem cercas de código.
        - Use apenas evidências presentes nos arquivos. Nunca invente arquivo, linha, trecho ou falha.
        - Se a evidência for indireta, use confidence "baixa" e explique a limitação no campo impact.
        - Cite o caminho relativo exato e uma linha aproximada. O campo evidence deve ter um trecho curto e literal.
        - Use um check_id exatamente igual a um id do checklist. Se nenhum se aplicar, use "pest-manual".
        - Não reporte dependências desatualizadas, CVEs de pacotes ou problemas já cobertos pela análise de lockfiles.
        - Não inclua segredos, tokens ou valores sensíveis na resposta.
        - Máximo de 8 achados por bloco, priorizando impacto e confiança.
        - Todo achado precisa de fix_prompt completo, pronto para colar em um agente de código.
        - Escreva em \(language), de forma direta e técnica.
        - Se não houver achados, devolva findings vazio e um summary explicando o que foi revisado.

        Formato exato:
        {"summary":"resumo do que foi revisado e do risco geral","findings":[{"check_id":"id-do-checklist","severity":"critical|high|medium|low","title":"falha curta","file":"caminho/relativo.ext","line":123,"evidence":"trecho literal curto","impact":"o que um atacante consegue fazer","recommendation":"correção concreta","fix_prompt":"prompt completo para o agente corrigir","confidence":"alta|media|baixa"}],"limitations":["limite da análise"]}
        """

        let user = """
        Projeto: \(project.name)
        Caminho: \(project.path)
        Bloco \(chunkIndex) de \(chunkCount).

        Use o checklist e os arquivos abaixo. Procure brechas e oportunidades de hardening.
        \(payload)
        """

        let content = try await completePest(system: system, user: user, configuration: configuration)
        return try parsePest(
            content,
            project: project,
            checks: checks,
            allowedPaths: Set(files.map(\.path))
        )
    }

    private func resolveConfiguration() async throws -> LLMConfiguration {
        let settings = settingsProvider()
        let configuration: LLMConfiguration
        do {
            configuration = try settings.llmConfiguration()
        } catch {
            throw LLMError.authUnavailable(error.localizedDescription)
        }

        guard configuration.mode == .standard else { return configuration }

        var resolved = configuration
        do {
            resolved.token = try await authStore.validAccessToken()
        } catch {
            throw LLMError.authUnavailable(error.localizedDescription)
        }
        return resolved
    }

    private func completePest(
        system: String,
        user: String,
        configuration: LLMConfiguration
    ) async throws -> String {
        do {
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: configuration,
                jsonMode: true,
                maxTokens: 6_000,
                timeout: 240,
                reasoningEffort: "low",
                temperature: 0.1
            )
        } catch LLMError.requestFailed(let message) where message.contains("400") {
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: configuration,
                jsonMode: false,
                maxTokens: 6_000,
                timeout: 240,
                reasoningEffort: "low",
                temperature: 0.1
            )
        } catch LLMError.requestFailed(let message)
            where message.contains("401") || message.contains("403") {
            let refreshed = try await refreshedConfiguration(configuration)
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: refreshed,
                jsonMode: true,
                maxTokens: 6_000,
                timeout: 240,
                reasoningEffort: "low",
                temperature: 0.1
            )
        }
    }

    private func completeRedTeam(
        system: String,
        user: String,
        configuration: LLMConfiguration
    ) async throws -> String {
        do {
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: configuration,
                jsonMode: true,
                maxTokens: 8_000,
                timeout: 300,
                reasoningEffort: "low",
                temperature: 0.1
            )
        } catch LLMError.requestFailed(let message) where message.contains("400") {
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: configuration,
                jsonMode: false,
                maxTokens: 8_000,
                timeout: 300,
                reasoningEffort: "low",
                temperature: 0.1
            )
        } catch LLMError.requestFailed(let message)
            where message.contains("401") || message.contains("403") {
            let refreshed = try await refreshedConfiguration(configuration)
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: refreshed,
                jsonMode: true,
                maxTokens: 8_000,
                timeout: 300,
                reasoningEffort: "low",
                temperature: 0.1
            )
        }
    }

    private func complete(
        system: String,
        user: String,
        configuration: LLMConfiguration
    ) async throws -> String {
        do {
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: configuration,
                jsonMode: true
            )
        } catch LLMError.requestFailed(let message) where message.contains("400") {
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: configuration,
                jsonMode: false
            )
        } catch LLMError.requestFailed(let message)
            where message.contains("401") || message.contains("403") {
            let refreshed = try await refreshedConfiguration(configuration)
            return try await requestCompletion(
                system: system,
                user: user,
                configuration: refreshed,
                jsonMode: true
            )
        }
    }

    private func refreshedConfiguration(_ configuration: LLMConfiguration) async throws -> LLMConfiguration {
        guard configuration.mode == .standard else {
            // A chave RTX é fixa; se ela falhar, o erro real volta para a tela.
            return configuration
        }
        var refreshed = configuration
        do {
            refreshed.token = try await authStore.forceRefresh()
        } catch {
            throw LLMError.authUnavailable(error.localizedDescription)
        }
        return refreshed
    }

    private func requestCompletion(
        system: String,
        user: String,
        configuration: LLMConfiguration,
        jsonMode: Bool,
        maxTokens: Int = 16_000,
        timeout: TimeInterval = 120,
        reasoningEffort: String = "minimal",
        temperature: Double = 0.15
    ) async throws -> String {
        guard let token = configuration.token, !token.isEmpty else {
            throw LLMError.authUnavailable(
                configuration.mode == .rtx
                    ? LLMConfigurationError.missingKey.localizedDescription
                    : "Conecte sua conta da Cultura Builder."
            )
        }
        var body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens,
            "reasoning_effort": reasoningEffort
        ]
        if jsonMode {
            body["response_format"] = ["type": "json_object"]
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = data

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw LLMError.requestFailed(
                configuration.mode == .rtx
                    ? "Não consegui falar com o endpoint RTX. Confira a URL e a chave em Ajustes > Análises."
                    : "Não consegui falar com a LLM da Cultura Builder."
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.requestFailed("Resposta inválida da LLM.")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw LLMError.requestFailed(
                    configuration.mode == .rtx
                        ? "401 não autorizado. Confira a chave RTX em Ajustes > Análises."
                        : "401 não autorizado"
                )
            }
            if http.statusCode == 400 {
                throw LLMError.requestFailed("400 requisição recusada")
            }
            if http.statusCode == 429 {
                throw LLMError.requestFailed("Muitas análises em pouco tempo. Espere alguns segundos.")
            }
            throw LLMError.requestFailed("A LLM respondeu com erro \(http.statusCode).")
        }

        guard let root = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let choice = choices.first,
              let message = choice["message"] as? [String: Any] else {
            throw LLMError.invalidResponse("A LLM devolveu uma resposta inesperada.")
        }

        let content = (message["content"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !content.isEmpty { return content }

        let reasoning = (message["reasoning_content"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if reasoning.contains("\"headline\"") || reasoning.contains("\"projects\"") {
            return reasoning
        }

        if (choice["finish_reason"] as? String) == "length" {
            throw LLMError.invalidResponse("A LLM atingiu o limite de tokens antes de concluir.")
        }

        throw LLMError.invalidResponse("A LLM não devolveu um diagnóstico completo.")
    }

    private func makePayload(alerts: [ProjectAlert]) throws -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        var projects: [[String: Any]] = []
        for alert in alerts.prefix(12) {
            let packages = alert.packageAggregates.prefix(10).map { package -> [String: Any] in
                var item: [String: Any] = [
                    "nome": package.name,
                    "ecossistema": package.ecosystem,
                    "versao_instalada": package.installedVersion,
                    "severidade": package.severity.rawValue,
                    "kev": package.hasKEV,
                    "cves": package.cveIDs,
                    "total_cves": package.findings.count
                ]
                if let fixed = package.fixedVersion {
                    item["versao_corrigida"] = fixed
                }
                if let cvss = package.highestCVSS {
                    item["cvss_maximo"] = cvss
                }
                item["titulos"] = Array(package.findings.prefix(3).map(\.title))
                if let summary = package.findings.first(where: { $0.isKEV })?.summary
                    ?? package.findings.first?.summary,
                   !summary.isEmpty {
                    item["resumo"] = String(summary.prefix(320))
                }
                return item
            }

            projects.append([
                "nome": alert.project.name,
                "caminho": alert.project.path,
                "ecossistemas": alert.project.ecosystems,
                "lockfiles": alert.project.lockfiles,
                "risco_maximo": alert.risk.rawValue,
                "total_pacotes": alert.packageCount,
                "total_cves": alert.findings.count,
                "pacotes": Array(packages),
                "outros_pacotes": max(0, alert.packageCount - 10)
            ])
        }

        let payload: [String: Any] = [
            "data": formatter.string(from: Date()),
            "total_projetos": alerts.count,
            "total_cves": alerts.reduce(0) { $0 + $1.findings.count },
            "projetos": projects
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func makeRedTeamPayload(
        project: ProjectRef,
        files: [RedTeamSourceFile],
        chunkIndex: Int,
        chunkCount: Int
    ) throws -> String {
        let payload: [String: Any] = [
            "projeto": [
                "nome": project.name,
                "caminho": project.path
            ],
            "bloco": "\(chunkIndex) de \(chunkCount)",
            "arquivos": files.map { file in
                [
                    "caminho": file.path,
                    "bytes": file.bytes,
                    "conteudo": file.content
                ]
            }
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func makePestPayload(
        project: ProjectRef,
        checks: [PestCheck],
        files: [PestSourceFile],
        chunkIndex: Int,
        chunkCount: Int
    ) throws -> String {
        let checklist: [[String: Any]] = checks.map { check in
            [
                "id": check.id,
                "titulo": check.title,
                "categoria": check.category,
                "severidade": check.severity.rawValue,
                "tags": check.tags,
                "orientacao": check.guidance,
                "correcao": check.remediation,
                "nuclei": check.nuclei,
                "nuclei_id": check.nucleiID
            ]
        }
        let payload: [String: Any] = [
            "projeto": [
                "nome": project.name,
                "caminho": project.path
            ],
            "bloco": "\(chunkIndex) de \(chunkCount)",
            "checklist": checklist,
            "arquivos": files.map { file in
                [
                    "caminho": file.path,
                    "bytes": file.bytes,
                    "truncado": file.truncated,
                    "conteudo": file.content
                ]
            }
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func parsePest(
        _ content: String,
        project: ProjectRef,
        checks: [PestCheck],
        allowedPaths: Set<String>
    ) throws -> PestLLMResult {
        let json = Self.extractJSONObject(from: content)
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Não consegui interpretar o relatório do Pest.")
        }

        let rawSummary = (root["summary"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summary = PestReader.redact(rawSummary).text
        let limitations = (root["limitations"] as? [String] ?? [])
            .map { PestReader.redact($0.trimmingCharacters(in: .whitespacesAndNewlines)).text }
            .filter { !$0.isEmpty }

        let checkByID = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
        var findings: [PestFinding] = []
        for item in (root["findings"] as? [[String: Any]] ?? []) {
            let title = (item["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let file = (item["file"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !file.isEmpty else { continue }
            guard allowedPaths.contains(file) else { continue }

            let rawCheckID = (item["check_id"] as? String)
                ?? (item["check"] as? String)
                ?? "pest-manual"
            let check = checkByID[rawCheckID]
            let severity = parseRedTeamSeverity(item["severity"] as? String)
            let rawLine = (item["line"] as? NSNumber)?.intValue
                ?? (item["line"] as? String).flatMap(Int.init)
            let line = rawLine.map { max(1, $0) }
            let evidence = (item["evidence"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let impact = (item["impact"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let recommendation = (item["recommendation"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let confidence = (item["confidence"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "media"
            let rawFixPrompt = (item["fix_prompt"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let category = check?.category ?? "Pest"
            let nuclei = check?.nuclei
            let fallbackCheck = PestCheck(
                id: rawCheckID,
                title: title,
                category: category,
                severity: severity,
                nuclei: nuclei ?? "",
                nucleiID: check?.nucleiID ?? "",
                tags: [],
                languages: [],
                fileHints: [],
                guidance: impact,
                remediation: recommendation,
                patterns: []
            )
            let fixPrompt = rawFixPrompt.isEmpty
                ? PestPromptBuilder.fixPrompt(
                    project: project,
                    check: check ?? fallbackCheck,
                    file: file,
                    line: line,
                    evidence: PestReader.maskEvidence(evidence)
                )
                : rawFixPrompt

            findings.append(
                PestFinding(
                    severity: severity,
                    title: title,
                    checkID: rawCheckID,
                    category: category,
                    nuclei: nuclei,
                    file: file,
                    line: line,
                    evidence: PestReader.maskEvidence(evidence, limit: 600),
                    impact: String(impact.prefix(1_400)),
                    recommendation: String(recommendation.prefix(1_400)),
                    fixPrompt: String(fixPrompt.prefix(4_000)),
                    confidence: confidence.lowercased(),
                    source: .ia
                )
            )
        }

        guard !summary.isEmpty || !findings.isEmpty else {
            throw LLMError.invalidResponse("O Pest devolveu um relatório vazio.")
        }

        return PestLLMResult(
            summary: summary,
            findings: Array(findings.prefix(8)),
            limitations: Array(limitations.prefix(6))
        )
    }

    private func parseRedTeam(_ content: String) throws -> RedTeamLLMResult {
        let json = Self.extractJSONObject(from: content)
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Não consegui interpretar o relatório de Red Teaming.")
        }

        let summary = (root["summary"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let limitations = (root["limitations"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var findings: [RedTeamFinding] = []
        for item in (root["findings"] as? [[String: Any]] ?? []) {
            let title = (item["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let file = (item["file"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !file.isEmpty else { continue }

            let line = (item["line"] as? NSNumber)?.intValue
                ?? (item["line"] as? String).flatMap(Int.init)
            let evidence = (item["evidence"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let impact = (item["impact"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let recommendation = (item["recommendation"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let confidence = (item["confidence"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "media"
            let severity = parseRedTeamSeverity(item["severity"] as? String)

            findings.append(
                RedTeamFinding(
                    severity: severity,
                    title: title,
                    file: file,
                    line: line,
                    evidence: String(evidence.prefix(600)),
                    impact: String(impact.prefix(1_200)),
                    recommendation: String(recommendation.prefix(1_200)),
                    confidence: confidence.lowercased()
                )
            )
        }

        guard !summary.isEmpty || !findings.isEmpty else {
            throw LLMError.invalidResponse("O Red Teaming devolveu um relatório vazio.")
        }

        return RedTeamLLMResult(
            summary: summary,
            findings: Array(findings.prefix(15)),
            limitations: Array(limitations.prefix(8))
        )
    }

    private func parseRedTeamSeverity(_ raw: String?) -> RiskLevel {
        switch (raw ?? "").lowercased() {
        case "critical", "critica", "crítica":
            return .critical
        case "high", "alta", "alto":
            return .high
        case "medium", "media", "média", "medio", "médio":
            return .medium
        case "low", "baixa", "baixo":
            return .low
        default:
            return .unknown
        }
    }

    private func parseDiagnosis(
        _ content: String,
        alerts: [ProjectAlert]
    ) throws -> LLMDiagnosis {
        let json = Self.extractJSONObject(from: content)
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Não consegui interpretar o diagnóstico da LLM.")
        }

        let headline = (root["headline"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summary = (root["summary"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextSteps = (root["next_steps"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var byPath = Dictionary(uniqueKeysWithValues: alerts.map { ($0.project.path, $0) })
        var byName: [String: ProjectAlert] = [:]
        for alert in alerts where byName[alert.project.name] == nil {
            byName[alert.project.name] = alert
        }

        var projects: [LLMProjectDiagnosis] = []
        for item in (root["projects"] as? [[String: Any]] ?? []) {
            let rawPath = (item["path"] as? String)
                ?? (item["caminho"] as? String)
                ?? ""
            let match = byPath[rawPath] ?? byName[rawPath]
            guard let match else { continue }

            let riskRaw = (item["risk"] as? String) ?? (item["risco"] as? String)
            let diagnosis = (item["diagnosis"] as? String)
                ?? (item["diagnostico"] as? String)
                ?? ""
            let recommendation = (item["recommendation"] as? String)
                ?? (item["recomendacao"] as? String)
                ?? ""
            let fixPrompt = (item["fix_prompt"] as? String) ?? ""

            let projectHeadline = (item["headline"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !diagnosis.isEmpty || !recommendation.isEmpty || !fixPrompt.isEmpty else {
                continue
            }

            projects.append(
                LLMProjectDiagnosis(
                    projectPath: match.project.path,
                    risk: riskRaw.flatMap(RiskLevel.init(rawValue:)),
                    headline: projectHeadline,
                    diagnosis: diagnosis.trimmingCharacters(in: .whitespacesAndNewlines),
                    recommendation: recommendation.trimmingCharacters(in: .whitespacesAndNewlines),
                    fixPrompt: fixPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )

            byPath.removeValue(forKey: match.project.path)
            byName.removeValue(forKey: match.project.name)
        }

        guard !headline.isEmpty || !summary.isEmpty || !projects.isEmpty else {
            throw LLMError.invalidResponse("A LLM devolveu um diagnóstico vazio.")
        }

        return LLMDiagnosis(
            headline: headline,
            summary: summary,
            nextSteps: Array(nextSteps.prefix(5)),
            projects: projects
        )
    }

    static func extractJSONObject(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let start = cleaned.firstIndex(of: "{") else { return cleaned }

        var depth = 0
        var inString = false
        var escaped = false
        var index = start

        while index < cleaned.endIndex {
            let character = cleaned[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(cleaned[start...index])
                    }
                }
            }
            index = cleaned.index(after: index)
        }
        return String(cleaned[start...])
    }
}
