import Foundation

public enum PromptBuilder {
    public static func build(
        for alert: ProjectAlert,
        diagnosis: String? = nil,
        recommendation: String? = nil,
        llmPlan: String? = nil
    ) -> String {
        let packages = alert.packageAggregates
        let lines = header(
            name: alert.project.name,
            path: alert.project.path,
            ecosystems: alert.project.ecosystems,
            packages: packages
        )

        var output = lines
        if let diagnosis, !diagnosis.isEmpty {
            output.append("")
            output.append("Diagnóstico:")
            output.append(diagnosis)
        }
        if let recommendation, !recommendation.isEmpty {
            output.append("")
            output.append("Orientação adicional:")
            output.append(recommendation)
        }

        output.append("")
        output.append("Achados verificados:")
        for package in packages {
            output.append(contentsOf: packageLines(package))
        }

        let overflow = packages.reduce(0) { partial, package in
            partial + max(0, package.findings.count - 12)
        }
        if overflow > 0 {
            output.append("")
            output.append("Há mais vulnerabilidades além das listadas acima. Consulte o relatório completo no Builders Protect.")
        }

        output.append("")
        output.append("Plano de correção:")
        output.append(contentsOf: planLines(for: alert.project, packages: packages))

        if let llmPlan,
           isUsefulPlan(llmPlan, projectPath: alert.project.path, findings: alert.findings) {
            output.append("")
            output.append("Plano complementar sugerido pela Cultura Builder:")
            output.append(llmPlan.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        output.append("")
        output.append(contentsOf: rulesLines)
        output.append("")
        output.append("Critérios de conclusão:")
        output.append("- Nenhuma das vulnerabilidades listadas acima continua presente nas versões instaladas.")
        output.append("- Lockfiles atualizados e consistentes com os manifests.")
        output.append("- Build, testes e auditoria de dependências executados sem regressões.")
        output.append("- O relatório final informa arquivos alterados, versões antes/depois, testes executados e riscos remanescentes.")

        return output.joined(separator: "\n")
    }

    public static func buildCombined(for alerts: [ProjectAlert]) -> String {
        let sorted = alerts.sorted { lhs, rhs in
            if lhs.risk != rhs.risk { return lhs.risk > rhs.risk }
            return lhs.project.name.localizedStandardCompare(rhs.project.name) == .orderedAscending
        }
        let packagesTotal = sorted.reduce(0) { $0 + $1.packageCount }
        let date = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .short
        )

        var output: [String] = [
            "# Correção de vulnerabilidades — todos os projetos",
            "",
            "Você está trabalhando nos projetos locais listados abaixo. A tarefa é corrigir as vulnerabilidades conhecidas nas dependências de todos eles, com mudanças pequenas, verificáveis e sem refatorações não relacionadas.",
            "",
            "Contexto:",
            "- Projetos afetados: \(sorted.count)",
            "- Pacotes afetados: \(packagesTotal)",
            "- Prompt gerado em: \(date) pelo Builders Protect, da Cultura Builder",
            "",
            "## Projetos e prioridades"
        ]

        for alert in sorted {
            output.append(
                "- \(alert.risk.shortLabel) — \(alert.project.name) — \(packagesTotalLabel(alert.packageCount)) — \(alert.project.path)"
            )
        }

        output.append("")
        output.append("## Ordem de trabalho")
        output.append("1. Resolva um projeto por vez, começando pelo de maior risco. Não misture mudanças de projetos diferentes no mesmo commit ou na mesma rodada de testes.")
        output.append("2. Em cada projeto, leia os manifests e lockfiles, confirme as versões instaladas e atualize apenas os pacotes afetados.")
        output.append("3. Rode a auditoria de dependências e a suíte de testes do projeto antes de passar para o próximo.")
        output.append("4. Ao final, entregue um relatório separado por projeto com versões antes/depois, arquivos alterados, testes executados e riscos remanescentes.")

        for (index, alert) in sorted.enumerated() {
            let packages = alert.packageAggregates
            output.append("")
            output.append("## \(index + 1). \(alert.project.name) — \(alert.risk.shortLabel)")
            output.append("- Caminho: \(alert.project.path)")
            output.append(
                "- Ecossistemas: \(alert.project.ecosystems.isEmpty ? "não identificado" : alert.project.ecosystems.joined(separator: ", "))"
            )
            output.append("- Pacotes afetados: \(alert.packageCount)")

            if !alert.headline.isEmpty {
                output.append("- Resumo: \(alert.headline)")
            }
            if !alert.diagnosis.isEmpty {
                output.append("")
                output.append("Diagnóstico:")
                output.append(alert.diagnosis)
            }
            if !alert.recommendation.isEmpty {
                output.append("")
                output.append("Orientação adicional:")
                output.append(alert.recommendation)
            }

            output.append("")
            output.append("### Pacotes e versões")
            for package in packages {
                output.append(contentsOf: packageLines(package, headingLevel: "####"))
            }

            output.append("")
            output.append("### Plano deste projeto")
            output.append(contentsOf: planLines(for: alert.project, packages: packages))
        }

        output.append("")
        output.append(contentsOf: rulesLines)
        output.append("")
        output.append("Critérios de conclusão:")
        output.append("- Todos os projetos listados foram tratados, não apenas o primeiro.")
        output.append("- Nenhuma das vulnerabilidades listadas continua presente nas versões instaladas.")
        output.append("- Lockfiles atualizados e consistentes com os manifests de cada projeto.")
        output.append("- Build, testes e auditoria de dependências executados em cada projeto sem regressões.")
        output.append("- O relatório final separa os resultados por projeto e informa arquivos alterados, versões antes/depois, testes executados e riscos remanescentes.")

        return output.joined(separator: "\n")
    }

    private static func packagesTotalLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "pacote" : "pacotes")"
    }

    private static func header(
        name: String,
        path: String,
        ecosystems: [String],
        packages: [PackageAggregate]
    ) -> [String] {
        let date = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .short
        )
        return [
            "# Correção de vulnerabilidades — \(name)",
            "",
            "Você está trabalhando no projeto local abaixo. A tarefa é corrigir vulnerabilidades conhecidas nas dependências, com mudanças pequenas, verificáveis e sem refatorações não relacionadas.",
            "",
            "Contexto:",
            "- Projeto: \(name)",
            "- Caminho: \(path)",
            "- Ecossistemas: \(ecosystems.isEmpty ? "não identificado" : ecosystems.joined(separator: ", "))",
            "- Pacotes afetados: \(packages.count)",
            "- Prompt gerado em: \(date) pelo Builders Protect, da Cultura Builder"
        ]
    }

    private static func packageLines(
        _ package: PackageAggregate,
        headingLevel: String = "##"
    ) -> [String] {
        var lines: [String] = []
        let severity = package.severity.label.lowercased()
        let kev = package.hasKEV ? " · EXPLORADA ATIVAMENTE (KEV)" : ""
        lines.append("")
        lines.append("\(headingLevel) \(package.name)@\(package.installedVersion) (\(package.ecosystem)) — \(severity)\(kev)")

        if let fixed = package.fixedVersion {
            lines.append("- Versão corrigida mínima sugerida: \(fixed)")
        } else {
            lines.append("- Versão corrigida: atualizar para a última versão estável que corrija estas vulnerabilidades.")
        }

        for finding in package.findings.prefix(12) {
            var detail = "- \(finding.cveID)"
            if let cvss = finding.cvss {
                detail += String(format: " | CVSS %.1f", cvss)
            }
            if finding.isKEV {
                detail += " | KEV"
            }
            detail += " | \(finding.title)"
            if let fixed = finding.fixedVersion, fixed != package.fixedVersion {
                detail += " | corrigido em \(fixed)"
            }
            detail += " | \(finding.url)"
            lines.append(detail)
        }

        if package.findings.count > 12 {
            lines.append("- … e mais vulnerabilidades neste pacote.")
        }
        return lines
    }

    private static func planLines(
        for project: ProjectRef,
        packages: [PackageAggregate]
    ) -> [String] {
        var lines: [String] = []
        lines.append("1. Leia os manifests e lockfiles do projeto e confirme as versões instaladas antes de alterar qualquer coisa.")
        lines.append("2. Atualize cada pacote afetado para pelo menos a versão corrigida indicada, preferindo a menor atualização capaz de corrigir todas as vulnerabilidades do pacote.")
        lines.append("3. Atualize também dependências transitivas quando o gerenciador exigir; não edite o lockfile à mão.")

        let hints = packageManagerHints(for: project, packages: packages)
        if !hints.isEmpty {
            lines.append("4. Use os comandos adequados ao projeto:")
            lines.append(contentsOf: hints.map { "   - \($0)" })
        }

        lines.append("5. Rode a auditoria de dependências e a suíte de testes do projeto. Corrija apenas regressões causadas pela atualização.")
        lines.append("6. Se uma atualização exigir mudança de código, faça a menor mudança possível e explique o motivo.")
        lines.append("7. Se não for possível corrigir alguma vulnerabilidade, documente o bloqueio, o risco e uma mitigação temporária.")
        return lines
    }

    private static func packageManagerHints(
        for project: ProjectRef,
        packages: [PackageAggregate]
    ) -> [String] {
        var hints: [String] = []
        let ecosystems = Set(project.ecosystems)
        let lockfiles = Set(project.lockfiles)

        if ecosystems.contains("npm") {
            let sample = packages.first { $0.ecosystem == "npm" }
            let target = sample.map { package in
                if let fixed = package.fixedVersion {
                    return "\(package.name)@\(fixed)"
                }
                return package.name
            } ?? "<pacote>"
            if lockfiles.contains("pnpm-lock.yaml") {
                hints.append("pnpm update \(target)")
                hints.append("pnpm audit")
            } else if lockfiles.contains("yarn.lock") {
                hints.append("yarn up \(target)")
                hints.append("yarn npm audit --all")
            } else if lockfiles.contains("bun.lock") {
                hints.append("bun update \(target)")
                hints.append("bun audit")
            } else {
                hints.append("npm install \(target)")
                hints.append("npm audit")
            }
        }

        if ecosystems.contains("pypi") {
            if lockfiles.contains("poetry.lock") {
                hints.append("poetry update <pacote>")
                hints.append("poetry run pip-audit")
            } else {
                hints.append("pip install -U <pacote>")
                hints.append("pip-audit -r requirements.txt")
            }
        }

        if ecosystems.contains("cargo") {
            let sample = packages.first { $0.ecosystem == "cargo" }
            if let sample, let fixed = sample.fixedVersion {
                hints.append("cargo update -p \(sample.name) --precise \(fixed)")
            } else {
                hints.append("cargo update -p <pacote>")
            }
            hints.append("cargo audit")
        }

        if ecosystems.contains("go") {
            hints.append("go get <módulo>@<versão-corrigida>")
            hints.append("go mod tidy")
            hints.append("govulncheck ./...")
        }

        if ecosystems.contains("rubygems") {
            hints.append("bundle update <gem>")
            hints.append("bundle audit check --update")
        }

        if ecosystems.contains("hex") {
            hints.append("mix deps.update <pacote>")
            hints.append("mix hex.audit")
        }

        if ecosystems.contains("nix") {
            hints.append("nix flake update")
        }

        if hints.isEmpty {
            hints.append("Use o gerenciador de pacotes já adotado pelo projeto e gere o lockfile novamente.")
        }

        return hints
    }

    private static func isUsefulPlan(
        _ plan: String,
        projectPath: String,
        findings: [DependencyFinding]
    ) -> Bool {
        let trimmed = plan.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 200, trimmed.count <= 8_000 else { return false }
        if trimmed.contains(projectPath) { return true }
        return findings.contains { trimmed.contains($0.cveID) }
    }

    private static let rulesLines: [String] = [
        "Regras:",
        "- Trabalhe somente no projeto indicado pelo caminho acima.",
        "- Não faça refatorações, renomeações ou atualizações não relacionadas às vulnerabilidades listadas.",
        "- Não remova nem desabilite testes para fazer o build passar.",
        "- Não leia, imprima, grave ou faça commit de segredos, tokens ou arquivos .env.",
        "- Preserve a compatibilidade pública do projeto sempre que possível.",
        "- Não faça commit nem push; deixe as mudanças no working tree para revisão.",
        "- Se precisar de uma decisão de produto ou de uma migração incompatível, pare e explique a opção mais segura."
    ]
}
