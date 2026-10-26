import CVECore
import SwiftUI

enum RedTeamingFeature {
    static let isEnabled = false
}

struct RedTeamView: View {
    @ObservedObject var model: AppModel

    @State private var consent = false

    var body: some View {
        if RedTeamingFeature.isEnabled {
            enabledContent
        } else {
            comingSoon
        }
    }

    private var comingSoon: some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Red Teaming")
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text("Análise profunda de código, um projeto por vez")
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                Spacer()

                Text("EM BREVE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(CBTheme.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(CBTheme.surface, in: Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            hairline

            VStack(alignment: .leading, spacing: 14) {
                NoticeCard(
                    kind: .info,
                    title: "Red Teaming está desativado por enquanto",
                    message: "A análise profunda de código está temporariamente indisponível enquanto investigamos um problema de consumo de memória. Nenhum código é enviado nesta versão."
                )

                Text("A análise de dependências continua funcionando normalmente.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Spacer()

            hairline

            HStack(spacing: 8) {
                Text("Builders Protect · v\(BrandAssets.version)")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enabledContent: some View {
        VStack(spacing: 0) {
            header
            hairline

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    projectCard
                    consentCard
                    actionCard
                    reportContent
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }

            hairline
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(message: toast)
                    .padding(.bottom, 58)
            }
        }
        .task {
            if model.redTeamProjects.isEmpty {
                model.loadRedTeamProjects()
            }
        }
        .onChange(of: model.redTeamProjectPath) { _ in
            consent = false
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(CBTheme.hairline)
            .frame(height: 1)
    }

    private var header: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Red Teaming")
                    .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("Análise profunda de código, um projeto por vez")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(model.authStatus.connected ? CBTheme.mint : CBTheme.high)
                    .frame(width: 6, height: 6)
                Text(model.authStatus.connected ? "IA conectada" : "IA desconectada")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CBTheme.surface, in: Capsule())

            Button {
                model.loadRedTeamProjects()
            } label: {
                Label("Atualizar projetos", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SurfaceButtonStyle())
            .disabled(model.isLoadingRedTeamProjects || model.isRedTeamRunning)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Vai além das dependências")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("O Red Teaming revisa o código do projeto escolhido em busca de falhas de autenticação, injection, exposição de dados e outras vulnerabilidades que não aparecem no lockfile. A análise usa uma LLM privada da Cultura Builder: os dados não são enviados para laboratórios de IA nem usados para treinamento. Pode levar vários minutos.")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(CBTheme.lime.opacity(0.045), in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous))
    }

    private var projectCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Projeto")
                    Spacer()
                    if model.isLoadingRedTeamProjects {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                    }
                }

                if model.isLoadingRedTeamProjects && model.redTeamProjects.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                        Text("Procurando projetos nas pastas monitoradas…")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else if model.redTeamProjects.isEmpty {
                    NoticeCard(
                        kind: .warning,
                        title: "Nenhum projeto encontrado",
                        message: "Adicione uma pasta com lockfiles em Ajustes > Pastas para liberar a análise profunda.",
                        actionTitle: "Abrir Pastas",
                        action: { model.settingsSection = .folders }
                    )
                } else {
                    Menu {
                        ForEach(model.redTeamProjects) { project in
                            Button {
                                model.selectRedTeamProject(project.path)
                            } label: {
                                Text(project.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CBTheme.lime)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.selectedRedTeamProject?.name ?? "Selecionar projeto")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CBTheme.text)
                                Text(
                                    model.selectedRedTeamProject?.path.homeAbbreviated
                                        ?? "Escolha um projeto da lista"
                                )
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(CBTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(CBTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(model.isRedTeamRunning)

                    if let project = model.selectedRedTeamProject {
                        HStack(spacing: 8) {
                            Label(project.ecosystems.joined(separator: ", "), systemImage: "shippingbox")
                            Text("·")
                            Text(Vocabulary.quantity(project.lockfiles.count, "lockfile", "lockfiles"))
                        }
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                    }
                }
            }
        }
    }

    private var consentCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Consentimento")

                NoticeCard(
                    kind: .warning,
                    title: "O código deste projeto será enviado para a LLM privada da Cultura Builder",
                    message: "Somente os arquivos de texto do projeto escolhido são enviados para a LLM privada da Cultura Builder. .env, chaves, credenciais, binários, lockfiles, dependências instaladas e arquivos grandes são ignorados. Segredos reconhecíveis são redigidos antes do envio. Os dados não são enviados a laboratórios de IA nem usados para treinamento. A análise pode demorar e consumir tokens."
                )

                Toggle(isOn: $consent) {
                    Text("Autorizo o envio do código deste projeto para a LLM privada da Cultura Builder.")
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
                .disabled(model.isRedTeamRunning || model.selectedRedTeamProject == nil)
            }
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.authStatus.connected {
                NoticeCard(
                    kind: .info,
                    title: "Conecte a conta para usar o Red Teaming",
                    message: "A análise profunda depende da LLM da Cultura Builder.",
                    actionTitle: "Abrir Conta",
                    action: { model.settingsSection = .account }
                )
            }

            if model.isRedTeamRunning {
                ScanProgressCard(
                    progress: model.redTeamProgress.map {
                        ScanProgress(phase: $0.phase, detail: $0.detail, fraction: $0.fraction)
                    }
                )

                Button {
                    model.cancelRedTeam()
                } label: {
                    Label("Cancelar análise", systemImage: "xmark")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
            } else {
                Button {
                    model.startRedTeam()
                } label: {
                    Label("Iniciar análise profunda", systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(LimeButtonStyle(fullWidth: true))
                .disabled(!model.canRunRedTeam || !consent)

                Text("A análise não altera seus arquivos e não faz commit. Você pode continuar usando o app enquanto ela roda.")
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            if let error = model.redTeamError {
                NoticeCard(kind: .error, title: "A análise não terminou", message: error)
            }
        }
    }

    @ViewBuilder
    private var reportContent: some View {
        if let report = model.redTeamReport {
            VStack(alignment: .leading, spacing: 14) {
                reportHeader(report)

                if report.findings.isEmpty {
                    NoticeCard(
                        kind: .success,
                        title: "Nenhuma falha de código encontrada",
                        message: Vocabulary.prose(report.summary)
                    )
                } else {
                    ForEach(report.findings) { finding in
                        RedTeamFindingCard(finding: finding)
                    }
                }

                if !report.limitations.isEmpty {
                    limitations(report.limitations)
                }
            }
        }
    }

    private func reportHeader(_ report: RedTeamReport) -> some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            SectionLabel(text: "Último relatório")
                            if report.risk != .unknown {
                                RiskBadge(risk: report.risk, compact: true)
                            }
                        }
                        Text(report.projectName)
                            .font(.system(size: 18, weight: .light, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("\(report.finishedAt.relativeShort) · \(report.filesAnalyzed) arquivos · \(max(1, report.bytesAnalyzed / 1000)) KB")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    Spacer()

                    Text("\(report.findings.count)")
                        .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(report.risk.color)
                }

                Text(Vocabulary.prose(report.summary))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    private func limitations(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "Limites desta análise")
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(CBTheme.textTertiary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)
                    Text(Vocabulary.prose(item))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("O Red Teaming usa a LLM privada da Cultura Builder e não altera seus arquivos.")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            Spacer()
            Button {
                model.settingsSection = .account
            } label: {
                Label("Conta", systemImage: "person.crop.circle")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
    }
}

private struct RedTeamFindingCard: View {
    let finding: RedTeamFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        RiskBadge(risk: finding.severity, compact: true)
                        Text(finding.confidence.uppercased())
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    Text(Vocabulary.prose(finding.title))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(finding.location)
                        .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }

            if !finding.evidence.isEmpty {
                Text(finding.evidence)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .textSelection(.enabled)
            }

            if !finding.impact.isEmpty {
                labeledText("Impacto", Vocabulary.prose(finding.impact))
            }
            if !finding.recommendation.isEmpty {
                labeledText("Como corrigir", Vocabulary.prose(finding.recommendation))
            }
        }
        .padding(15)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous))
    }

    private func labeledText(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(text: label)
            Text(text)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
