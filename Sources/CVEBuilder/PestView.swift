import CVECore
import SwiftUI

struct PestView: View {
    @ObservedObject var model: AppModel

    @State private var consent = false
    @State private var showConsentSheet = false
    @State private var pendingResume = false
    @State private var showClearDialog = false
    @State private var clearAllReports = false
    @State private var showProjectPicker = false
    @State private var routineHour = 9
    @State private var routineMinute = 0
    @State private var routineError: String?
    @State private var formLoadedFor: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        intro
                        projectCard { path in
                            model.selectPestProject(path)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo("pest-routine", anchor: .top)
                            }
                        }
                        memoryCard
                        actionCard
                        routineCard
                            .id("pest-routine")
                        reportContent
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
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
            if model.pestProjects.isEmpty {
                model.loadPestProjects()
            }
            syncRoutineForm(force: true)
        }
        .onChange(of: model.pestProjectPath) { _ in
            consent = false
            pendingResume = false
            showConsentSheet = false
            syncRoutineForm(force: true)
        }
        .onChange(of: model.pestRoutineForSelectedProject?.updatedAt) { _ in
            syncRoutineForm(force: false)
        }
        .onChange(of: model.isPestRunning) { running in
            if !running { consent = false }
        }
        .sheet(isPresented: $showConsentSheet, onDismiss: { pendingResume = false }) {
            PestConsentSheet(
                projectName: model.selectedPestProject?.name ?? L10n.t("este projeto", "this project"),
                isResume: pendingResume,
                onCancel: {
                    showConsentSheet = false
                    pendingResume = false
                },
                onAuthorize: authorizePestStart
            )
        }
        .sheet(isPresented: $showProjectPicker) {
            PestProjectPickerSheet(model: model)
        }
        .confirmationDialog(
            clearAllReports
                ? L10n.t("Limpar todos os relatórios do Pest?", "Clear all Pest reports?")
                : L10n.t("Limpar este relatório do Pest?", "Clear this Pest report?"),
            isPresented: $showClearDialog,
            titleVisibility: .visible
        ) {
            Button(
                clearAllReports
                    ? L10n.t("Limpar todos", "Clear all")
                    : L10n.t("Limpar relatório", "Clear report"),
                role: .destructive
            ) {
                if clearAllReports {
                    model.clearAllPestReports()
                } else {
                    model.clearSelectedPestReport()
                }
            }
            Button(L10n.t("Cancelar", "Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("Os achados salvos serão removidos deste Mac. A próxima análise começa do zero."))
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
                HStack(spacing: 8) {
                    Text(L10n.t("Pest"))
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text(L10n.t("NUCLEI GUIDE"))
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }
                Text(L10n.t("Segurança de código, um projeto por vez"))
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
                model.loadPestProjects()
            } label: {
                Label(L10n.t("Atualizar projetos"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(SurfaceButtonStyle())
            .disabled(model.isLoadingPestProjects || model.isPestRunning)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Um caçador de brechas, não um scanner de rede"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("O Pest usa um checklist destilado do catálogo de templates do Nuclei para revisar autenticação, injection, exposição de dados, configuração e outros riscos do projeto escolhido. A varredura é estática: não executa o projeto, não instala dependências e não faz requisições ao alvo. A revisão semântica usa a LLM privada da Cultura Builder; os arquivos são redigidos e enviados em blocos pequenos após o seu consentimento."))
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            CBTheme.lime.opacity(0.045),
            in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
        )
    }

    private func projectCard(onConfigureRoutine: @escaping (String) -> Void) -> some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    SectionLabel(text: L10n.t("Meus projetos"))
                    Spacer()
                    if model.isLoadingPestProjects {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                    }
                    if !model.pestProjects.isEmpty {
                        Text(L10n.t("\(model.activePestProjects.count) de \(model.pestProjects.count)", "\(model.activePestProjects.count) of \(model.pestProjects.count)"))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                        Button {
                            showProjectPicker = true
                        } label: {
                            Label(L10n.t("Gerenciar"), systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(model.isLoadingPestProjects || model.isPestRunning)
                    }
                }

                if model.isLoadingPestProjects && model.pestProjects.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                        Text(L10n.t("Procurando projetos nas pastas monitoradas…"))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else if model.pestProjects.isEmpty {
                    NoticeCard(
                        kind: .warning,
                        title: L10n.t("Nenhum projeto encontrado"),
                        message: L10n.t("Adicione uma pasta com manifests ou código em Ajustes > Pastas para liberar o Pest."),
                        actionTitle: L10n.t("Abrir Pastas"),
                        action: { model.settingsSection = .folders }
                    )
                } else if model.activePestProjects.isEmpty {
                    NoticeCard(
                        kind: .info,
                        title: L10n.t("Nenhum projeto na lista"),
                        message: L10n.t("Escolha os projetos que você acompanha no Pest. Eles ficam à mão para analisar e configurar a rotina sem procurar a pasta de novo."),
                        actionTitle: L10n.t("Escolher projetos"),
                        action: { showProjectPicker = true }
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(model.activePestProjects) { project in
                            projectRow(project, onConfigureRoutine: onConfigureRoutine)
                        }
                    }

                    Text(L10n.t("Clique em um projeto para abrir o relatório e ajustar a rotina. O botão de play analisa na hora; cada rotina usa um horário próprio, com pelo menos 30 minutos de diferença."))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func projectRow(
        _ project: ProjectRef,
        onConfigureRoutine: @escaping (String) -> Void
    ) -> some View {
        let selected = model.pestProjectPath == project.path
        let routine = model.pestState.routines.first { $0.projectPath == project.path }

        return HStack(spacing: 10) {
            Button {
                model.selectPestProject(project.path)
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(selected ? CBTheme.lime : Color.clear)
                        .frame(width: 2, height: 30)

                    Image(systemName: selected ? "folder.fill" : "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? CBTheme.lime : CBTheme.textSecondary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                            .lineLimit(1)
                        Text(project.path.homeAbbreviated)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(CBTheme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 6) {
                            Text(project.ecosystems.joined(separator: ", "))
                            if !project.lockfiles.isEmpty {
                                Text(L10n.t("·"))
                                Text(Vocabulary.quantity(project.lockfiles.count, "lockfile", "lockfiles"))
                            }
                            Text(L10n.t("·"))
                            if let routine {
                                Text(
                                    routine.enabled
                                        ? L10n.t("rotina \(routine.timeLabel)", "routine \(routine.timeLabel)")
                                        : L10n.t("rotina pausada", "routine paused")
                                )
                                .foregroundStyle(routine.enabled ? CBTheme.mint : CBTheme.textTertiary)
                            } else {
                                Text(L10n.t("sem rotina"))
                            }
                        }
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isPestRunning)

            HStack(spacing: 6) {
                Button {
                    onConfigureRoutine(project.path)
                } label: {
                    Image(systemName: "clock.badge.checkmark")
                }
                .buttonStyle(
                    IconButtonStyle(
                        size: 28,
                        tint: routine?.enabled == true ? CBTheme.mint : CBTheme.textSecondary
                    )
                )
                .help(L10n.t("Configurar rotina deste projeto"))
                .disabled(model.isPestRunning)

                Button {
                    model.requestRedTeam(projectPath: project.path)
                } label: {
                    Image(systemName: "shield.lefthalf.filled")
                }
                .buttonStyle(IconButtonStyle(size: 28, tint: CBTheme.lime.opacity(0.8)))
                .help(L10n.t("Acionar o Red Team neste projeto"))
                .disabled(model.isRedTeamRunning)

                Button {
                    analyze(project)
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(IconButtonStyle(size: 28, tint: CBTheme.lime))
                .help(L10n.t("Analisar este projeto agora"))
                .disabled(model.isPestRunning || !model.llmReady)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            selected ? CBTheme.lime.opacity(0.07) : CBTheme.surface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? CBTheme.lime.opacity(0.35) : Color.clear, lineWidth: 1)
        }
    }

    private func analyze(_ project: ProjectRef) {
        model.selectPestProject(project.path)
        requestPestStart()
    }

    private var memoryCard: some View {
        let snapshot = PestMemoryGuard.snapshot()
        let budget = PestMemoryGuard.budget(for: snapshot)
        return SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    SectionLabel(text: L10n.t("Memória e espaço"))
                    Spacer()
                    Text(L10n.t("IMPORTANTE"))
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }

                HStack(alignment: .top, spacing: 22) {
                    memoryMetric(
                        L10n.t("Memória livre", "Free memory"),
                        PestMemoryGuard.formatBytes(snapshot.availableBytes),
                        detail: L10n.t("mínimo \(PestMemoryGuard.formatBytes(PestMemoryGuard.minimumAvailableBytes))", "minimum \(PestMemoryGuard.formatBytes(PestMemoryGuard.minimumAvailableBytes))")
                    )
                    memoryMetric(
                        L10n.t("Disco livre", "Free disk"),
                        snapshot.diskAvailableBytes.map { PestMemoryGuard.formatBytes(UInt64(max($0, 0))) } ?? "—",
                        detail: L10n.t("mínimo \(PestMemoryGuard.formatBytes(UInt64(PestMemoryGuard.minimumDiskBytes)))", "minimum \(PestMemoryGuard.formatBytes(UInt64(PestMemoryGuard.minimumDiskBytes)))")
                    )
                    memoryMetric(
                        L10n.t("Orçamento", "Budget"),
                        budget.map { PestMemoryGuard.formatBytes($0.maxRSSGrowthBytes) } ?? L10n.t("indisponível", "unavailable"),
                        detail: budget.map { L10n.t("\($0.maxFiles) arquivos · \(PestMemoryGuard.formatBytes(UInt64($0.maxTotalBytes)))", "\($0.maxFiles) files · \(PestMemoryGuard.formatBytes(UInt64($0.maxTotalBytes)))") }
                            ?? L10n.t("feche apps pesados", "close heavy apps")
                    )
                }

                Text(L10n.t("Para uma análise confortável, deixe pelo menos 2 GB de memória livre e 500 MB de disco. O Pest pausa e salva o progresso se o Mac ficar abaixo do mínimo; você pode retomar depois."))
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if budget == nil {
                    NoticeCard(
                        kind: .warning,
                        title: L10n.t("Memória abaixo do mínimo seguro"),
                        message: L10n.t("Feche navegadores, Docker ou apps pesados e volte ao Pest. A análise não começa até haver espaço para trabalhar sem travar o Mac.")
                    )
                }
            }
        }
    }

    private func memoryMetric(_ label: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(CBTheme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .light, design: .rounded))
                .foregroundStyle(CBTheme.text)
            Text(detail)
                .font(.system(size: 8.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isPestRunning {
                ScanProgressCard(
                    progress: model.pestProgress.map {
                        ScanProgress(phase: $0.phase, detail: $0.detail, fraction: $0.fraction)
                    }
                )

                if consent {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.shield.fill")
                        Text(L10n.t("Consentimento autorizado para esta análise."))
                    }
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(CBTheme.mint)
                }

                Button {
                    model.cancelPest()
                } label: {
                    Label(L10n.t("Cancelar análise"), systemImage: "xmark")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(CBTheme.lime.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CBTheme.lime)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.t("Pest com IA"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("A revisão usa a LLM privada da Cultura Builder. O consentimento é pedido antes de cada análise manual; salvar uma rotina autoriza a execução diária."))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    Spacer(minLength: 8)

                    Text(L10n.t("OBRIGATÓRIO"))
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }
                .padding(11)
                .background(
                    CBTheme.lime.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if !model.llmReady {
                    NoticeCard(
                        kind: .warning,
                        title: model.isHackMode
                            ? L10n.t("Cole a chave RTX para usar o Pest", "Paste the RTX key to use Pest")
                            : L10n.t("Conecte a conta para usar o Pest", "Connect your account to use Pest"),
                        message: model.isHackMode
                            ? L10n.t("O modo RTX usa uma chave dedicada em Ajustes > IA e segurança.", "RTX mode uses a dedicated key in Settings > AI and security.")
                            : L10n.t("O Pest usa a IA da Cultura Builder em todas as análises. Entre na sua conta para liberar o botão de análise.", "Pest uses Cultura Builder AI in every analysis. Sign in to unlock the analyze button."),
                        actionTitle: model.isHackMode
                            ? L10n.t("Abrir IA e segurança", "Open AI and security")
                            : L10n.t("Abrir Conta", "Open Account"),
                        action: { model.settingsSection = model.isHackMode ? .ai : .account }
                    )
                }

                if model.pestResumeAvailable {
                    HStack(spacing: 10) {
                        Button {
                            requestPestStart(resume: true)
                        } label: {
                            Label(L10n.t("Retomar análise pausada"), systemImage: "play.fill")
                        }
                        .buttonStyle(LimeButtonStyle())
                        .disabled(!canStart)

                        Button {
                            requestPestStart()
                        } label: {
                            Label(L10n.t("Nova análise"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .disabled(!canStart)
                    }
                } else {
                    Button {
                        requestPestStart()
                    } label: {
                        Label(L10n.t("Analisar com Pest"), systemImage: "scope")
                    }
                    .buttonStyle(LimeButtonStyle(fullWidth: true))
                    .disabled(!canStart)
                }

                Text(L10n.t("O Pest não altera seus arquivos e não faz commit. Você pode continuar usando o app enquanto ele roda."))
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            if let error = model.pestError {
                NoticeCard(kind: .error, title: L10n.t("O Pest não terminou"), message: error)
            }
        }
    }

    private var canStart: Bool {
        model.canRunPest
    }

    private func requestPestStart(resume: Bool = false) {
        guard canStart else { return }
        pendingResume = resume
        showConsentSheet = true
    }

    private func authorizePestStart() {
        let resume = pendingResume
        consent = true
        pendingResume = false
        showConsentSheet = false
        model.startPest(resume: resume)
    }

    private var routineCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: L10n.t("Rotina diária"))
                    Spacer()
                    if let next = model.pestNextRunDate {
                        Text(L10n.t("próxima \(shortNextRun(next))", "next \(shortNextRun(next))"))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                }

                Text(L10n.t("Cada projeto pode ter a própria rotina diária. O Pest respeita pelo menos 30 minutos entre rotinas e pausa se a memória ficar baixa."))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.selectedPestProject != nil {
                    HStack(spacing: 8) {
                        Picker(L10n.t("Hora"), selection: $routineHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 62)

                        Text(L10n.t(":"))
                            .font(.system(size: 15, weight: .light, design: .monospaced))
                            .foregroundStyle(CBTheme.textTertiary)

                        Picker(L10n.t("Minuto"), selection: $routineMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 62)

                        Spacer()

                        Text(L10n.t("com IA"))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    if let conflict = routineConflict {
                        NoticeCard(
                            kind: .warning,
                            title: L10n.t("Horário indisponível"),
                            message: conflict
                        )
                    }

                    if let routine = model.pestRoutineForSelectedProject {
                        Text(L10n.t("Rotina \(routine.enabled ? "ativa" : "pausada") às \(routine.timeLabel). \(nextRunDescription(for: routine))", "Routine \(routine.enabled ? "active" : "paused") at \(routine.timeLabel). \(nextRunDescription(for: routine))"))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    } else {
                        Text(L10n.t("Sem rotina para este projeto. O Pest também pode ser executado manualmente a qualquer momento."))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    Text(L10n.t("A rotina usa a IA da Cultura Builder e só roda com a conta conectada. Salvar a rotina autoriza o envio recorrente dos mesmos arquivos redigidos para a LLM privada, uma vez ao dia."))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 9) {
                        Button {
                            saveRoutine()
                        } label: {
                            Label(
                                model.pestRoutineForSelectedProject == nil
                                    ? L10n.t("Criar rotina", "Create routine")
                                    : L10n.t("Salvar alterações", "Save changes"),
                                systemImage: "clock.badge.checkmark"
                            )
                        }
                        .buttonStyle(LimeButtonStyle())
                        .disabled(routineConflict != nil)

                        Button {
                            suggestRoutineTime()
                        } label: {
                            Label(L10n.t("Sugerir horário"), systemImage: "wand.and.stars")
                        }
                        .buttonStyle(SurfaceButtonStyle())

                        if let routine = model.pestRoutineForSelectedProject {
                            Button {
                                model.removePestRoutine(id: routine.id)
                                routineError = nil
                                syncRoutineForm(force: true)
                            } label: {
                                Label(L10n.t("Remover"), systemImage: "trash")
                            }
                            .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
                        }
                    }
                } else {
                    Text(L10n.t("Selecione um projeto para configurar a rotina."))
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                if let routineError {
                    NoticeCard(kind: .error, title: L10n.t("Rotina não salva"), message: routineError)
                }

                if !model.pestState.routines.isEmpty {
                    Rectangle()
                        .fill(CBTheme.hairline)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: L10n.t("Rotinas configuradas"))
                        ForEach(model.pestState.routines) { routine in
                            routineRow(routine)
                        }
                    }
                }
            }
        }
    }

    private func routineRow(_ routine: PestRoutine) -> some View {
        HStack(spacing: 9) {
            Toggle(
                "",
                isOn: Binding(
                    get: { routine.enabled },
                    set: { model.setPestRoutineEnabled(id: routine.id, enabled: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)

            VStack(alignment: .leading, spacing: 1) {
                Text(routine.projectName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                    .lineLimit(1)
                Text(L10n.t("\(routine.timeLabel) · IA · \(nextRunDescription(for: routine))", "\(routine.timeLabel) · AI · \(nextRunDescription(for: routine))"))
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                analyze(routine.project)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(IconButtonStyle(size: 26, tint: CBTheme.lime))
            .help(L10n.t("Analisar este projeto agora"))
            .disabled(
                model.isPestRunning
                    || !model.llmReady
                    || !model.pestProjects.contains(where: { $0.path == routine.projectPath })
            )

            Button {
                if model.pestProjects.contains(where: { $0.path == routine.projectPath }) {
                    model.selectPestProject(routine.projectPath)
                    routineHour = routine.hour
                    routineMinute = routine.minute
                    formLoadedFor = routine.projectPath
                    routineError = nil
                } else {
                    routineError = L10n.t("A pasta deste projeto não está mais monitorada.", "This project's folder is no longer monitored.")
                }
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(IconButtonStyle(size: 26))

            Button {
                let wasSelected = model.pestRoutineForSelectedProject?.id == routine.id
                model.removePestRoutine(id: routine.id)
                if wasSelected {
                    syncRoutineForm(force: true)
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(IconButtonStyle(size: 26, tint: CBTheme.textTertiary))
        }
        .padding(.vertical, 2)
    }

    private var routineConflict: String? {
        guard let project = model.selectedPestProject else { return nil }
        return model.pestRoutineConflict(
            hour: routineHour,
            minute: routineMinute,
            projectPath: project.path,
            excluding: model.pestRoutineForSelectedProject?.id
        )
    }

    private func saveRoutine() {
        guard let project = model.selectedPestProject else { return }
        routineError = model.savePestRoutine(
            project: project,
            hour: routineHour,
            minute: routineMinute
        )
        if routineError == nil {
            syncRoutineForm(force: true)
        }
    }

    private func suggestRoutineTime() {
        guard let project = model.selectedPestProject else { return }
        guard let slot = PestRoutinePlanner.suggestedSlot(
            desiredHour: routineHour,
            desiredMinute: routineMinute,
            projectPath: project.path,
            routines: model.pestState.routines,
            excluding: model.pestRoutineForSelectedProject?.id
        ) else {
            routineError = L10n.t("Não encontrei um horário livre com 30 minutos de intervalo.", "I could not find a free time with a 30-minute gap.")
            return
        }
        routineHour = slot.hour
        routineMinute = slot.minute
        routineError = nil
    }

    private func syncRoutineForm(force: Bool) {
        guard let project = model.selectedPestProject else {
            formLoadedFor = nil
            return
        }
        guard force || formLoadedFor != project.path else { return }
        if let routine = model.pestRoutineForSelectedProject {
            routineHour = routine.hour
            routineMinute = routine.minute
        } else {
            routineHour = 9
            routineMinute = 0
        }
        formLoadedFor = project.path
        routineError = nil
    }

    private func nextRunDescription(for routine: PestRoutine) -> String {
        guard routine.enabled else { return L10n.t("pausada", "paused") }
        guard let next = PestRoutinePlanner.nextRunDate(for: routine) else {
            return L10n.t("sem próxima data", "no next date")
        }
        if next.timeIntervalSinceNow < 60 { return L10n.t("assim que possível", "as soon as possible") }
        return shortNextRun(next)
    }

    private func shortNextRun(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.t("hoje às \(time)", "today at \(time)")
        }
        if calendar.isDateInTomorrow(date) {
            return L10n.t("amanhã às \(time)", "tomorrow at \(time)")
        }
        formatter.locale = L10n.locale
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var reportContent: some View {
        if let report = model.selectedPestReport {
            VStack(alignment: .leading, spacing: 14) {
                reportHeader(report)

                if report.paused {
                    NoticeCard(
                        kind: .warning,
                        title: L10n.t("Análise pausada"),
                        message: L10n.t(report.pauseReason ?? L10n.t("O Pest pausou para proteger a memória do Mac.", "Pest paused to protect the Mac's memory.")),
                        actionTitle: canStart ? L10n.t("Retomar agora", "Resume now") : nil,
                        action: canStart ? { requestPestStart(resume: true) } : nil
                    )
                }

                if report.findings.isEmpty {
                    NoticeCard(
                        kind: report.paused ? .info : .success,
                        title: report.paused
                            ? L10n.t("Nenhum achado nos blocos já analisados", "No findings in the chunks analyzed so far")
                            : L10n.t("Nenhuma brecha confirmada", "No confirmed flaw"),
                        message: Vocabulary.prose(report.summary)
                    )
                } else {
                    ForEach(report.findings) { finding in
                        PestFindingCard(finding: finding) {
                            model.copyPestFixPrompt(finding)
                        }
                    }
                }

                if !report.limitations.isEmpty {
                    limitations(report.limitations)
                }
            }
        }
    }

    private func reportHeader(_ report: PestReport) -> some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            SectionLabel(text: report.paused
                                ? L10n.t("Relatório parcial", "Partial report")
                                : L10n.t("Último relatório", "Last report"))
                            if report.risk != .unknown {
                                RiskBadge(risk: report.risk, compact: true)
                            }
                        }
                        Text(report.projectName)
                            .font(.system(size: 20, weight: .light, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("\(report.finishedAt.relativeShort) · \(report.filesAnalyzed) arquivos · \(max(1, report.bytesAnalyzed / 1000)) KB", "\(report.finishedAt.relativeShort) · \(report.filesAnalyzed) files · \(max(1, report.bytesAnalyzed / 1000)) KB"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(report.findings.count)")
                            .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(report.risk.color)
                        Text(report.llmUsed ? L10n.t("com IA", "with AI") : L10n.t("local", "local"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                }

                Text(Vocabulary.prose(report.summary))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        model.copyPestSummary(report)
                    } label: {
                        Label(L10n.t("Copiar resumo"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))

                    Button {
                        clearAllReports = false
                        showClearDialog = true
                    } label: {
                        Label(L10n.t("Limpar"), systemImage: "trash")
                    }
                    .buttonStyle(GhostButtonStyle(tint: CBTheme.critical))
                    .disabled(model.isPestRunning)

                    Button {
                        clearAllReports = true
                        showClearDialog = true
                    } label: {
                        Label(L10n.t("Limpar tudo"), systemImage: "trash")
                    }
                    .buttonStyle(GhostButtonStyle(tint: CBTheme.critical))
                    .disabled(model.isPestRunning)

                    Text(L10n.t("\(report.checksApplied.count) checks · \(report.chunksAnalyzed) bloco(s)", "\(report.checksApplied.count) checks · \(report.chunksAnalyzed) chunk(s)"))
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }
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
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L10n.t("Pest: análise estática guiada pelo catálogo Nuclei. Não executa o projeto nem faz requisições ao alvo."))
                .font(.system(size: 12, weight: .regular, design: .rounded))
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

private struct PestProjectPickerSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredProjects: [ProjectRef] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return model.pestProjects }
        return model.pestProjects.filter {
            $0.name.localizedCaseInsensitiveContains(term)
                || $0.path.localizedCaseInsensitiveContains(term)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            searchBar
            divider

            Group {
                if model.isLoadingPestProjects && model.pestProjects.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                        Text(L10n.t("Procurando projetos nas pastas monitoradas…"))
                            .font(.system(size: 11.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.pestProjects.isEmpty {
                    NoticeCard(
                        kind: .warning,
                        title: L10n.t("Nenhum projeto encontrado"),
                        message: L10n.t("Adicione uma pasta com manifests ou código em Ajustes > Pastas para liberar o Pest.")
                    )
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else if filteredProjects.isEmpty {
                    Text(L10n.t("Nenhum projeto corresponde à busca."))
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    projectList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            divider
            footer
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(CBTheme.background)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CBTheme.limeMuted)
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CBTheme.lime)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Projetos do Pest"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("Escolha os projetos que ficam na lista de acesso rápido. Você pode analisar e configurar a rotina de cada um sem procurar a pasta novamente."))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle(size: 27))
            .help(L10n.t("Fechar"))
        }
        .padding(20)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CBTheme.textTertiary)
            TextField(L10n.t("Buscar por nome ou caminho", "Search by name or path"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.text)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CBTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var projectList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(filteredProjects) { project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func projectRow(_ project: ProjectRef) -> some View {
        let active = model.isPestProjectActive(project.path)
        let routine = model.pestState.routines.first { $0.projectPath == project.path }

        return Button {
            model.setPestProjectActive(project.path, active: !active)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: active ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? CBTheme.lime : CBTheme.textTertiary)
                    .frame(width: 17)

                Image(systemName: active ? "folder.fill" : "folder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? CBTheme.lime : CBTheme.textSecondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                        .lineLimit(1)
                    Text(project.path.homeAbbreviated)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                if let routine {
                    Text(routine.enabled
                        ? L10n.t("Rotina \(routine.timeLabel)", "Routine \(routine.timeLabel)")
                        : L10n.t("Rotina pausada", "Routine paused"))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(routine.enabled ? CBTheme.mint : CBTheme.textTertiary)
                } else {
                    Text(L10n.t("Sem rotina"))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                if active {
                    Text(L10n.t("NA LISTA"))
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                active ? CBTheme.lime.opacity(0.06) : CBTheme.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? CBTheme.lime.opacity(0.3) : Color.clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(L10n.t("\(model.activePestProjects.count) selecionado(s). As alterações são salvas automaticamente.", "\(model.activePestProjects.count) selected. Changes are saved automatically."))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            Spacer()
            Button(L10n.t("Concluir")) {
                dismiss()
            }
            .buttonStyle(LimeButtonStyle())
        }
        .padding(20)
    }

    private var divider: some View {
        Rectangle()
            .fill(CBTheme.hairline)
            .frame(height: 1)
    }
}

private struct PestConsentSheet: View {
    let projectName: String
    let isResume: Bool
    let onCancel: () -> Void
    let onAuthorize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    Circle()
                        .fill(CBTheme.lime.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                }

                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: L10n.t("Consentimento do Pest"))
                    Text(isResume
                        ? L10n.t("Retomar a análise com IA", "Resume the AI analysis")
                        : L10n.t("Analisar com IA", "Analyze with AI"))
                        .font(.system(size: 21, weight: .light, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text(projectName)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                Spacer()
            }

            NoticeCard(
                kind: .warning,
                title: L10n.t("Arquivos de texto do projeto serão enviados para a LLM privada"),
                message: L10n.t("Somente arquivos de código e configuração do projeto escolhido são enviados, em blocos pequenos, para a LLM privada da Cultura Builder. Sem o consentimento, a análise não começa.")
            )

            VStack(alignment: .leading, spacing: 9) {
                consentLine(L10n.t("Somente arquivos de código e configuração do projeto escolhido.", "Only code and configuration files from the chosen project."))
                consentLine(L10n.t(".env, chaves, credenciais, binários, lockfiles e dependências instaladas ficam de fora.", ".env, keys, credentials, binaries, lockfiles and installed dependencies stay out."))
                consentLine(L10n.t("Segredos reconhecíveis são mascarados antes do envio. Os dados não são usados para treinamento.", "Recognizable secrets are masked before sending. Data is not used for training."))
            }

            Text(L10n.t("O consentimento vale apenas para esta execução. Na próxima análise, o app pergunta de novo."))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(L10n.t("Agora não", "Not now"), action: onCancel)
                    .buttonStyle(GhostButtonStyle())

                Spacer()

                Button(action: onAuthorize) {
                    Label(
                        isResume
                            ? L10n.t("Autorizar e retomar", "Authorize and resume")
                            : L10n.t("Autorizar e analisar", "Authorize and analyze"),
                        systemImage: "checkmark.shield.fill"
                    )
                }
                .buttonStyle(LimeButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 540)
        .background(CBTheme.background)
    }

    private func consentLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(CBTheme.mint)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PestFindingCard: View {
    let finding: PestFinding
    let onCopyPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        RiskBadge(risk: finding.severity, compact: true)
                        Text(L10n.t(finding.confidence).uppercased())
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(CBTheme.textTertiary)
                        Text(L10n.t(finding.category).uppercased())
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(CBTheme.textTertiary)
                        if finding.source == .ia {
                            Text(L10n.t("IA"))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(CBTheme.lime)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(CBTheme.lime.opacity(0.1), in: Capsule())
                        }
                    }
                    Text(Vocabulary.prose(finding.title))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(finding.location)
                        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }

            if !finding.evidence.isEmpty {
                Text(finding.evidence)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2.5)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.black.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .textSelection(.enabled)
            }

            if !finding.impact.isEmpty {
                labeledText(L10n.t("Impacto", "Impact"), Vocabulary.prose(finding.impact))
            }
            if !finding.recommendation.isEmpty {
                labeledText(L10n.t("Como corrigir", "How to fix"), Vocabulary.prose(finding.recommendation))
            }

            HStack(spacing: 8) {
                Button {
                    onCopyPrompt()
                } label: {
                    Label(L10n.t("Copiar prompt de correção"), systemImage: "doc.on.doc.fill")
                }
                .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))

                if let nuclei = finding.nuclei {
                    Text("Nuclei · \(nuclei)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(15)
        .background(
            CBTheme.surface,
            in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
        )
    }

    private func labeledText(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(text: label)
            Text(text)
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
