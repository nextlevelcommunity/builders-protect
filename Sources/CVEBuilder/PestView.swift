import CVECore
import SwiftUI

struct PestView: View {
    @ObservedObject var model: AppModel

    @State private var consent = false
    @State private var routineHour = 9
    @State private var routineMinute = 0
    @State private var routineUseAI = true
    @State private var routineError: String?
    @State private var formLoadedFor: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    projectCard
                    memoryCard
                    consentCard
                    actionCard
                    routineCard
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
            if model.pestProjects.isEmpty {
                model.loadPestProjects()
            }
            syncRoutineForm(force: true)
        }
        .onChange(of: model.pestProjectPath) { _ in
            consent = false
            syncRoutineForm(force: true)
        }
        .onChange(of: model.pestRoutineForSelectedProject?.updatedAt) { _ in
            syncRoutineForm(force: false)
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
                    Text("Pest")
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text("NUCLEI GUIDE")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }
                Text("Segurança de código, um projeto por vez")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(model.authStatus.connected ? CBTheme.mint : CBTheme.high)
                    .frame(width: 6, height: 6)
                Text(model.authStatus.connected ? "IA conectada" : "Análise local")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CBTheme.surface, in: Capsule())

            Button {
                model.loadPestProjects()
            } label: {
                Label("Atualizar projetos", systemImage: "arrow.clockwise")
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
                Text("Um caçador de brechas, não um scanner de rede")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("O Pest usa um checklist destilado do catálogo de templates do Nuclei para revisar autenticação, injection, exposição de dados, configuração e outros riscos do projeto escolhido. A análise local é estática: não executa o projeto, não instala dependências e não faz requisições ao alvo. Com a IA conectada, os arquivos são redigidos e enviados em blocos pequenos para a LLM privada da Cultura Builder.")
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

    private var projectCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Projeto")
                    Spacer()
                    if model.isLoadingPestProjects {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                    }
                }

                if model.isLoadingPestProjects && model.pestProjects.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CBTheme.lime)
                        Text("Procurando projetos nas pastas monitoradas…")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else if model.pestProjects.isEmpty {
                    NoticeCard(
                        kind: .warning,
                        title: "Nenhum projeto encontrado",
                        message: "Adicione uma pasta com manifests ou código em Ajustes > Pastas para liberar o Pest.",
                        actionTitle: "Abrir Pastas",
                        action: { model.settingsSection = .folders }
                    )
                } else {
                    Menu {
                        ForEach(model.pestProjects) { project in
                            Button {
                                model.selectPestProject(project.path)
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
                                Text(model.selectedPestProject?.name ?? "Selecionar projeto")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CBTheme.text)
                                Text(
                                    model.selectedPestProject?.path.homeAbbreviated
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
                        .background(
                            CBTheme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(model.isPestRunning)

                    if let project = model.selectedPestProject {
                        HStack(spacing: 8) {
                            Label(project.ecosystems.joined(separator: ", "), systemImage: "shippingbox")
                            if !project.lockfiles.isEmpty {
                                Text("·")
                                Text(Vocabulary.quantity(project.lockfiles.count, "lockfile", "lockfiles"))
                            }
                            if let routine = model.pestRoutineForSelectedProject {
                                Text("·")
                                Label(
                                    routine.enabled ? "rotina \(routine.timeLabel)" : "rotina pausada",
                                    systemImage: "clock"
                                )
                            }
                        }
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                    }
                }
            }
        }
    }

    private var memoryCard: some View {
        let snapshot = PestMemoryGuard.snapshot()
        let budget = PestMemoryGuard.budget(for: snapshot)
        return SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    SectionLabel(text: "Memória e espaço")
                    Spacer()
                    Text("IMPORTANTE")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }

                HStack(alignment: .top, spacing: 22) {
                    memoryMetric(
                        "Memória livre",
                        PestMemoryGuard.formatBytes(snapshot.availableBytes),
                        detail: "mínimo \(PestMemoryGuard.formatBytes(PestMemoryGuard.minimumAvailableBytes))"
                    )
                    memoryMetric(
                        "Disco livre",
                        snapshot.diskAvailableBytes.map { PestMemoryGuard.formatBytes(UInt64(max($0, 0))) } ?? "—",
                        detail: "mínimo \(PestMemoryGuard.formatBytes(UInt64(PestMemoryGuard.minimumDiskBytes)))"
                    )
                    memoryMetric(
                        "Orçamento",
                        budget.map { PestMemoryGuard.formatBytes($0.maxRSSGrowthBytes) } ?? "indisponível",
                        detail: budget.map { "\($0.maxFiles) arquivos · \(PestMemoryGuard.formatBytes(UInt64($0.maxTotalBytes)))" } ?? "feche apps pesados"
                    )
                }

                Text("Para uma análise confortável, deixe pelo menos 2 GB de memória livre e 500 MB de disco. O Pest pausa e salva o progresso se o Mac ficar abaixo do mínimo; você pode retomar depois.")
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if budget == nil {
                    NoticeCard(
                        kind: .warning,
                        title: "Memória abaixo do mínimo seguro",
                        message: "Feche navegadores, Docker ou apps pesados e volte ao Pest. A análise não começa até haver espaço para trabalhar sem travar o Mac."
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

    @ViewBuilder
    private var consentCard: some View {
        if model.authStatus.connected && model.pestUseAI {
            SurfaceCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Consentimento")

                    NoticeCard(
                        kind: .warning,
                        title: "Arquivos de texto do projeto serão enviados para a LLM privada",
                        message: "Somente arquivos de código e configuração do projeto escolhido são enviados, em blocos pequenos. .env, chaves, credenciais, binários, lockfiles, dependências instaladas e arquivos grandes são ignorados. Segredos reconhecíveis são mascarados antes do envio. Os dados não são usados para treinamento. A análise local continua disponível sem a IA."
                    )

                    Toggle(isOn: $consent) {
                        Text("Autorizo o envio do código deste projeto para a LLM privada da Cultura Builder.")
                            .font(.system(size: 11.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(model.isPestRunning || model.selectedPestProject == nil)
                }
            }
        } else if !model.authStatus.connected {
            NoticeCard(
                kind: .info,
                title: "IA desconectada: o Pest roda a análise local",
                message: "O checklist local continua funcionando. Conecte a conta para somar a revisão semântica da LLM privada da Cultura Builder.",
                actionTitle: "Abrir Conta",
                action: { model.settingsSection = .account }
            )
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isPestRunning {
                ScanProgressCard(
                    progress: model.pestProgress.map {
                        ScanProgress(phase: $0.phase, detail: $0.detail, fraction: $0.fraction)
                    }
                )

                Button {
                    model.cancelPest()
                } label: {
                    Label("Cancelar análise", systemImage: "xmark")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
            } else {
                Toggle(isOn: $model.pestUseAI) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Usar IA quando disponível")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("Sem IA, o Pest usa apenas o checklist local. A IA melhora a revisão semântica e o prompt de correção.")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(model.authStatus.connected == false)

                if model.pestResumeAvailable {
                    HStack(spacing: 10) {
                        Button {
                            model.startPest(resume: true)
                        } label: {
                            Label("Retomar análise pausada", systemImage: "play.fill")
                        }
                        .buttonStyle(LimeButtonStyle())
                        .disabled(!canStart)

                        Button {
                            model.startPest()
                        } label: {
                            Label("Nova análise", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .disabled(!canStart)
                    }
                } else {
                    Button {
                        consent = false
                        model.startPest()
                    } label: {
                        Label("Analisar com Pest", systemImage: "scope")
                    }
                    .buttonStyle(LimeButtonStyle(fullWidth: true))
                    .disabled(!canStart)
                }

                Text(
                    model.authStatus.connected && model.pestUseAI && !consent
                        ? "Marque o consentimento acima para enviar o código à IA. A análise local não precisa de consentimento."
                        : "O Pest não altera seus arquivos e não faz commit. Você pode continuar usando o app enquanto ele roda."
                )
                .font(.system(size: 9.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            }

            if let error = model.pestError {
                NoticeCard(kind: .error, title: "O Pest não terminou", message: error)
            }
        }
    }

    private var canStart: Bool {
        guard model.canRunPest else { return false }
        if model.authStatus.connected && model.pestUseAI {
            return consent
        }
        return true
    }

    private var routineCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Rotina diária")
                    Spacer()
                    if let next = model.pestNextRunDate {
                        Text("próxima \(shortNextRun(next))")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                }

                Text("Agende o Pest para analisar este projeto uma vez por dia. O app respeita pelo menos 30 minutos entre rotinas e pausa se a memória ficar baixa.")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.selectedPestProject != nil {
                    HStack(spacing: 8) {
                        Picker("Hora", selection: $routineHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 62)

                        Text(":")
                            .font(.system(size: 15, weight: .light, design: .monospaced))
                            .foregroundStyle(CBTheme.textTertiary)

                        Picker("Minuto", selection: $routineMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 62)

                        Spacer()

                        Toggle("Usar IA", isOn: $routineUseAI)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                    }

                    if let conflict = routineConflict {
                        NoticeCard(
                            kind: .warning,
                            title: "Horário indisponível",
                            message: conflict
                        )
                    }

                    if let routine = model.pestRoutineForSelectedProject {
                        Text("Rotina \(routine.enabled ? "ativa" : "pausada") às \(routine.timeLabel). \(nextRunDescription(for: routine))")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    } else {
                        Text("Sem rotina para este projeto. O Pest também pode ser executado manualmente a qualquer momento.")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    Text("Ao salvar com \"Usar IA\" ligado, você autoriza o envio recorrente dos mesmos arquivos redigidos para a LLM privada, uma vez ao dia.")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 9) {
                        Button {
                            saveRoutine()
                        } label: {
                            Label(
                                model.pestRoutineForSelectedProject == nil
                                    ? "Criar rotina"
                                    : "Salvar alterações",
                                systemImage: "clock.badge.checkmark"
                            )
                        }
                        .buttonStyle(LimeButtonStyle())
                        .disabled(routineConflict != nil)

                        Button {
                            suggestRoutineTime()
                        } label: {
                            Label("Sugerir horário", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(SurfaceButtonStyle())

                        if let routine = model.pestRoutineForSelectedProject {
                            Button {
                                model.removePestRoutine(id: routine.id)
                                routineError = nil
                                syncRoutineForm(force: true)
                            } label: {
                                Label("Remover", systemImage: "trash")
                            }
                            .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
                        }
                    }
                } else {
                    Text("Selecione um projeto para configurar a rotina.")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                if let routineError {
                    NoticeCard(kind: .error, title: "Rotina não salva", message: routineError)
                }

                if !model.pestState.routines.isEmpty {
                    Rectangle()
                        .fill(CBTheme.hairline)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Rotinas configuradas")
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
                Text("\(routine.timeLabel) · \(routine.useLLM ? "IA" : "local") · \(nextRunDescription(for: routine))")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                if model.pestProjects.contains(where: { $0.path == routine.projectPath }) {
                    model.selectPestProject(routine.projectPath)
                    routineHour = routine.hour
                    routineMinute = routine.minute
                    routineUseAI = routine.useLLM
                    formLoadedFor = routine.projectPath
                    routineError = nil
                } else {
                    routineError = "A pasta deste projeto não está mais monitorada."
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
            minute: routineMinute,
            useLLM: routineUseAI
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
            routineError = "Não encontrei um horário livre com 30 minutos de intervalo."
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
            routineUseAI = routine.useLLM
        } else {
            routineHour = 9
            routineMinute = 0
            routineUseAI = model.authStatus.connected
        }
        formLoadedFor = project.path
        routineError = nil
    }

    private func nextRunDescription(for routine: PestRoutine) -> String {
        guard routine.enabled else { return "pausada" }
        guard let next = PestRoutinePlanner.nextRunDate(for: routine) else { return "sem próxima data" }
        if next.timeIntervalSinceNow < 60 { return "assim que possível" }
        return shortNextRun(next)
    }

    private func shortNextRun(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "hoje às \(time)" }
        if calendar.isDateInTomorrow(date) { return "amanhã às \(time)" }
        formatter.dateFormat = "dd/MM 'às' HH:mm"
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
                        title: "Análise pausada",
                        message: report.pauseReason ?? "O Pest pausou para proteger a memória do Mac.",
                        actionTitle: canStart ? "Retomar agora" : nil,
                        action: canStart ? { model.startPest(resume: true) } : nil
                    )
                }

                if report.findings.isEmpty {
                    NoticeCard(
                        kind: report.paused ? .info : .success,
                        title: report.paused
                            ? "Nenhum achado nos blocos já analisados"
                            : "Nenhuma brecha confirmada",
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
                            SectionLabel(text: report.paused ? "Relatório parcial" : "Último relatório")
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

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(report.findings.count)")
                            .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(report.risk.color)
                        Text(report.llmUsed ? "com IA" : "local")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                }

                Text(Vocabulary.prose(report.summary))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        model.copyPestSummary(report)
                    } label: {
                        Label("Copiar resumo", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))

                    Text("\(report.checksApplied.count) checks · \(report.chunksAnalyzed) bloco(s)")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }
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
            Text("Pest: análise estática guiada pelo catálogo Nuclei. Não executa o projeto nem faz requisições ao alvo.")
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

private struct PestFindingCard: View {
    let finding: PestFinding
    let onCopyPrompt: () -> Void

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
                        Text(finding.category.uppercased())
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(CBTheme.textTertiary)
                        if finding.source == .ia {
                            Text("IA")
                                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                .foregroundStyle(CBTheme.lime)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(CBTheme.lime.opacity(0.1), in: Capsule())
                        }
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
                    .background(
                        Color.black.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .textSelection(.enabled)
            }

            if !finding.impact.isEmpty {
                labeledText("Impacto", Vocabulary.prose(finding.impact))
            }
            if !finding.recommendation.isEmpty {
                labeledText("Como corrigir", Vocabulary.prose(finding.recommendation))
            }

            HStack(spacing: 8) {
                Button {
                    onCopyPrompt()
                } label: {
                    Label("Copiar prompt de correção", systemImage: "doc.on.doc.fill")
                }
                .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))

                if let nuclei = finding.nuclei {
                    Text("Nuclei · \(nuclei)")
                        .font(.system(size: 8.5, weight: .regular, design: .monospaced))
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
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
