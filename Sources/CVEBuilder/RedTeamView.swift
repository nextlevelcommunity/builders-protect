import CVECore
import SwiftUI

enum RedTeamingFeature {
    static let isEnabled = true
}

struct RedTeamView: View {
    @ObservedObject var model: AppModel

    @State private var newHour = 9
    @State private var newMinute = 0
    @State private var routineError: String?

    private var consent: Binding<Bool> {
        Binding(
            get: { model.settings.redTeamConsent },
            set: { model.setRedTeamConsent($0) }
        )
    }

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
                    Text(L10n.t("Red Teaming"))
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text(L10n.t("Análise profunda de código, um projeto por vez"))
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                Spacer()

                Text(L10n.t("EM BREVE"))
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
                    title: L10n.t("Red Teaming está desativado por enquanto"),
                    message: L10n.t("A análise profunda de código está temporariamente indisponível enquanto investigamos um problema de consumo de memória. Nenhum código é enviado nesta versão.")
                )

                Text(L10n.t("A análise de dependências continua funcionando normalmente."))
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
                    routineCard
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
            routineError = nil
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
                Text(L10n.t("Red Teaming"))
                    .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("Análise profunda de código, um projeto por vez"))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(model.llmReady ? CBTheme.mint : CBTheme.high)
                    .frame(width: 6, height: 6)
                Text(model.llmReady
                    ? L10n.t("IA conectada", "AI connected")
                    : L10n.t("IA desconectada", "AI disconnected"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CBTheme.surface, in: Capsule())

            Button {
                model.loadRedTeamProjects()
            } label: {
                Label(L10n.t("Atualizar projetos"), systemImage: "arrow.clockwise")
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
                Text(L10n.t("Vai além das dependências"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("O Red Teaming revisa o código do projeto escolhido em busca de falhas de autenticação, injection, exposição de dados e outras vulnerabilidades que não aparecem no lockfile. A análise usa uma LLM privada da Cultura Builder: os dados não são enviados para laboratórios de IA nem usados para treinamento. Pode levar vários minutos."))
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
                    SectionLabel(text: L10n.t("Projeto"))
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
                        Text(L10n.t("Procurando projetos nas pastas monitoradas…"))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else if model.redTeamProjects.isEmpty {
                    NoticeCard(
                        kind: .warning,
                        title: L10n.t("Nenhum projeto encontrado"),
                        message: L10n.t("Adicione uma pasta com lockfiles em Ajustes > Pastas para liberar a análise profunda."),
                        actionTitle: L10n.t("Abrir Pastas"),
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
                                Text(model.selectedRedTeamProject?.name
                                    ?? L10n.t("Selecionar projeto", "Select project"))
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CBTheme.text)
                                Text(
                                    model.selectedRedTeamProject?.path.homeAbbreviated
                                        ?? L10n.t("Escolha um projeto da lista", "Choose a project from the list")
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
                            Text(L10n.t("·"))
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
                SectionLabel(text: L10n.t("Consentimento"))

                NoticeCard(
                    kind: .warning,
                    title: L10n.t("O código deste projeto será enviado para a LLM privada da Cultura Builder"),
                    message: L10n.t("Somente os arquivos de texto do projeto escolhido são enviados para a LLM privada da Cultura Builder. .env, chaves, credenciais, binários, lockfiles, dependências instaladas e arquivos grandes são ignorados. Segredos reconhecíveis são redigidos antes do envio. No modo RTX, o destino é o endpoint RTX. A análise roda em blocos, pode pausar por memória e pode ser retomada.")
                )

                Toggle(isOn: consent) {
                    Text(L10n.t("Autorizo o envio do código deste projeto para a LLM privada da Cultura Builder."))
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
                .disabled(model.isRedTeamRunning || model.selectedRedTeamProject == nil)
            }
        }
    }

    private var routineCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: L10n.t("Rodadas por dia"))
                    Spacer()
                    if let routine = model.redTeamRoutineForSelectedProject, !routine.slots.isEmpty {
                        Text(L10n.t("\(routine.slots.count) por dia", "\(routine.slots.count) per day"))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.lime)
                    }
                }

                Text(L10n.t("Agende quantas rodadas quiser no dia. Cada horário precisa de 20 minutos de diferença dos outros."))
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if let project = model.selectedRedTeamProject {
                    if let routine = model.redTeamRoutineForSelectedProject, !routine.slots.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(routine.slots) { slot in
                                HStack(spacing: 9) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(CBTheme.lime)
                                    Text(slot.label)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(CBTheme.text)
                                    Spacer()
                                    Button {
                                        model.removeRedTeamTime(projectPath: project.path, slotID: slot.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                    .buttonStyle(IconButtonStyle(size: 22))
                                    .help(L10n.t("Remover horário"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { routine.enabled },
                            set: { model.setRedTeamRoutineEnabled(projectPath: project.path, enabled: $0) }
                        )) {
                            Text(L10n.t("Rotina ativa"))
                                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                .foregroundStyle(CBTheme.textSecondary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(CBTheme.lime)
                    }

                    HStack(spacing: 8) {
                        Picker(L10n.t("Hora"), selection: $newHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 66)

                        Text(L10n.t(":"))
                            .foregroundStyle(CBTheme.textTertiary)

                        Picker(L10n.t("Minuto"), selection: $newMinute) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 66)

                        Button {
                            routineError = model.addRedTeamTime(
                                projectPath: project.path,
                                projectName: project.name,
                                hour: newHour,
                                minute: newMinute
                            )
                        } label: {
                            Label(L10n.t("Adicionar horário"), systemImage: "plus")
                        }
                        .buttonStyle(SurfaceButtonStyle())

                        Spacer()

                        if model.redTeamRoutineForSelectedProject != nil {
                            Button {
                                model.removeRedTeamRoutine(projectPath: project.path)
                                routineError = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(IconButtonStyle(size: 23))
                            .help(L10n.t("Remover rotina"))
                        }
                    }

                    if let routineError {
                        Text(routineError)
                            .font(.system(size: 9.3, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.high)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let next = model.redTeamNextRunDate {
                        Text(L10n.t("Próxima rodada: \(next.relativeShort)", "Next run: \(next.relativeShort)"))
                            .font(.system(size: 9.3, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                } else {
                    Text(L10n.t("Escolha um projeto para agendar rodadas."))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }
            }
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.llmReady {
                NoticeCard(
                    kind: .info,
                    title: model.isHackMode
                        ? L10n.t("Cole a chave RTX para usar o Red Team", "Paste the RTX key to use Red Team")
                        : L10n.t("Conecte a conta para usar o Red Teaming", "Connect your account to use Red Teaming"),
                    message: model.isHackMode
                        ? L10n.t("O modo RTX usa uma chave dedicada em Ajustes > IA e segurança.", "RTX mode uses a dedicated key in Settings > AI and security.")
                        : L10n.t("A análise profunda depende da LLM da Cultura Builder.", "Deep analysis depends on Cultura Builder's LLM."),
                    actionTitle: model.isHackMode
                        ? L10n.t("Abrir IA e segurança", "Open AI and security")
                        : L10n.t("Abrir Conta", "Open Account"),
                    action: { model.settingsSection = model.isHackMode ? .ai : .account }
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
                    Label(L10n.t("Cancelar análise"), systemImage: "xmark")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
            } else {
                if model.redTeamResumeAvailable {
                    Button {
                        model.startRedTeam()
                    } label: {
                        Label(L10n.t("Retomar análise pausada"), systemImage: "play.fill")
                    }
                    .buttonStyle(LimeButtonStyle(fullWidth: true))
                    .disabled(!model.canRunRedTeam)
                }

                Button {
                    model.startRedTeam(projectPath: model.redTeamProjectPath, resume: false)
                } label: {
                    Label(
                        model.redTeamResumeAvailable
                            ? L10n.t("Nova análise do zero", "New analysis from scratch")
                            : L10n.t("Iniciar análise profunda", "Start deep analysis"),
                        systemImage: "shield.lefthalf.filled"
                    )
                }
                .buttonStyle(LimeButtonStyle(fullWidth: true))
                .disabled(!model.canRunRedTeam || !model.settings.redTeamConsent)

                Text(L10n.t("A análise não altera seus arquivos e não faz commit. Você pode continuar usando o app enquanto ela roda."))
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            if let error = model.redTeamError {
                NoticeCard(kind: .error, title: L10n.t("A análise não terminou"), message: error)
            }
        }
    }

    @ViewBuilder
    private var reportContent: some View {
        if let report = model.redTeamReport {
            VStack(alignment: .leading, spacing: 14) {
                reportHeader(report)

                if report.paused {
                    NoticeCard(
                        kind: .warning,
                        title: L10n.t("Análise pausada para proteger a memória"),
                        message: L10n.t(report.pauseReason ?? L10n.t("Retome quando o Mac estiver mais livre.", "Resume when the Mac is freer."))
                    )
                }

                if report.findings.isEmpty {
                    NoticeCard(
                        kind: .success,
                        title: L10n.t("Nenhuma falha de código encontrada"),
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
                            SectionLabel(text: L10n.t("Último relatório"))
                            if report.risk != .unknown {
                                RiskBadge(risk: report.risk, compact: true)
                            }
                        }
                        Text(report.projectName)
                            .font(.system(size: 18, weight: .light, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("\(report.finishedAt.relativeShort) · \(report.filesAnalyzed) arquivos · \(max(1, report.bytesAnalyzed / 1000)) KB", "\(report.finishedAt.relativeShort) · \(report.filesAnalyzed) files · \(max(1, report.bytesAnalyzed / 1000)) KB"))
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
            SectionLabel(text: L10n.t("Limites desta análise"))
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
            Text(L10n.t("O Red Teaming usa a LLM privada da Cultura Builder e não altera seus arquivos."))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            Spacer()
            Button {
                model.settingsSection = .account
            } label: {
                Label(L10n.t("Conta"), systemImage: "person.crop.circle")
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
                        Text(L10n.t(finding.confidence).uppercased())
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
                labeledText(L10n.t("Impacto", "Impact"), Vocabulary.prose(finding.impact))
            }
            if !finding.recommendation.isEmpty {
                labeledText(L10n.t("Como corrigir", "How to fix"), Vocabulary.prose(finding.recommendation))
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
