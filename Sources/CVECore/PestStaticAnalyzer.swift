import Foundation

public struct PestStaticAnalyzer: Sendable {
    public init() {}

    public func analyze(
        files: [PestSourceFile],
        checks: [PestCheck],
        project: ProjectRef
    ) -> [PestFinding] {
        var findings: [PestFinding] = []
        var seen = Set<String>()

        let compiled: [(check: PestCheck, regexes: [NSRegularExpression])] = checks.map { check in
            let regexes = check.patterns.compactMap { pattern in
                try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            }
            return (check, regexes)
        }

        for file in files {
            if Self.isTestPath(file.path) { continue }
            if file.redactions > 0,
               let line = file.firstRedactionLine,
               let check = checks.first(where: { $0.id == "hardcoded-secret" }) {
                let key = "\(check.id)|\(file.path)|\(line)"
                if seen.insert(key).inserted {
                    findings.append(
                        Self.makeFinding(
                            check: check,
                            project: project,
                            file: file.path,
                            line: line,
                            evidence: "Conteúdo mascarado como [REDACTED] antes de sair do Mac.",
                            confidence: "alta",
                            source: .local
                        )
                    )
                }
            }

            let lines = file.content.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            for (check, regexes) in compiled where !regexes.isEmpty {
                for (index, rawLine) in lines.enumerated().prefix(4_000) {
                    let line = String(rawLine.prefix(2_000))
                    guard !line.isEmpty else { continue }
                    for regex in regexes {
                        let range = NSRange(line.startIndex..<line.endIndex, in: line)
                        guard let match = regex.firstMatch(in: line, options: [], range: range),
                              let matchRange = Range(match.range, in: line) else {
                            continue
                        }
                        let evidence = PestReader.maskEvidence(String(line[matchRange]))
                        let key = "\(check.id)|\(file.path)|\(index + 1)|\(evidence)"
                        guard seen.insert(key).inserted else { continue }
                        findings.append(
                            Self.makeFinding(
                                check: check,
                                project: project,
                                file: file.path,
                                line: index + 1,
                                evidence: evidence,
                                confidence: check.id == "hardcoded-secret" ? "alta" : "media",
                                source: .local
                            )
                        )
                        if findings.count >= 80 { return findings }
                    }
                }
            }
        }
        return findings
    }

    public static func makeFinding(
        check: PestCheck,
        project: ProjectRef,
        file: String,
        line: Int?,
        evidence: String,
        confidence: String,
        source: PestFindingSource
    ) -> PestFinding {
        PestFinding(
            severity: check.severity,
            title: check.title,
            checkID: check.id,
            category: check.category,
            nuclei: check.nuclei.isEmpty ? nil : check.nuclei,
            file: file,
            line: line,
            evidence: evidence,
            impact: check.guidance,
            recommendation: check.remediation,
            fixPrompt: PestPromptBuilder.fixPrompt(
                project: project,
                check: check,
                file: file,
                line: line,
                evidence: evidence
            ),
            confidence: confidence,
            source: source
        )
    }

    private static func isTestPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.contains("/test/")
            || lower.contains("/tests/")
            || lower.contains("/spec/")
            || lower.contains("/__tests__/")
            || lower.contains("/fixtures/")
            || lower.contains("/mocks/")
            || lower.contains(".test.")
            || lower.contains(".spec.")
            || lower.contains("_test.")
            || lower.hasPrefix("test/")
            || lower.hasPrefix("tests/")
    }
}

public enum PestPromptBuilder {
    public static func fixPrompt(
        project: ProjectRef,
        check: PestCheck,
        file: String,
        line: Int?,
        evidence: String
    ) -> String {
        let location = line.map { "\(project.path)/\(file):\($0)" } ?? "\(project.path)/\(file)"
        return """
        Você é um engenheiro de segurança corrigindo um achado do Pest no projeto \(project.name).

        Achado: \(check.title)
        Categoria: \(check.category)
        Severidade: \(check.severity.label)
        Referência de conhecimento: \(check.nuclei.isEmpty ? check.id : "\(check.nuclei) (\(check.nucleiID))")
        Local: \(location)
        Evidência: \(evidence)

        O que revisar:
        \(check.guidance)

        O que fazer:
        1. Abra o arquivo e confirme o fluxo completo da entrada até a operação perigosa.
        2. Corrija a causa raiz, não apenas o trecho apontado. \(check.remediation)
        3. Procure o mesmo padrão em outros arquivos e rotas do projeto.
        4. Adicione ou ajuste testes que reproduzam o cenário e comprovem a correção.
        5. Rode os testes, o build e uma nova execução do Pest no projeto.

        Critérios de conclusão:
        - O achado não aparece mais no Pest.
        - O fluxo legítimo continua funcionando.
        - Não há segredo ou dado sensível em log, relatório ou commit.
        - A correção tem teste automatizado quando o projeto já usa testes.

        Não faça commit nem altere arquivos fora de \(project.path) sem autorização.
        """
    }
}
