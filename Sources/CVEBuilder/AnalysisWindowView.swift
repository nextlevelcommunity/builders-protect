import CVECore
import SwiftUI

struct AnalysisPanelView: View {
    @ObservedObject var model: AppModel

    @State private var expandedID: String?
    @State private var search = ""
    @State private var riskFilter: RiskFilter = .all
    @State private var onlyKEV = false
    @State private var exclusionCandidate: ProjectAlert?

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline

            if let report = model.report, report.hasFindings, !model.isScanning {
                filterBar(report)
                hairline
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    content
                        .padding(.horizontal, 28)
                        .padding(.vertical, 26)
                        .id("top")
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
                .onChange(of: model.report?.finishedAt) { _ in
                    proxy.scrollTo("top", anchor: .top)
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
        .confirmationDialog(
            "Ignorar pasta?",
            isPresented: Binding(
                get: { exclusionCandidate != nil },
                set: { if !$0 { exclusionCandidate = nil } }
            ),
            presenting: exclusionCandidate
        ) { alert in
            Button("Ignorar pasta", role: .destructive) {
                model.excludeProject(alert)
                exclusionCandidate = nil
            }
            Button("Cancelar", role: .cancel) {
                exclusionCandidate = nil
            }
        } message: { alert in
            Text("\(alert.project.name) não será mais verificada. A análise será atualizada agora; você pode reativar em Ajustes > Pastas.")
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
                Text("Análises")
                    .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("Resultados da última varredura")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CBTheme.surface, in: Capsule())

            if let report = model.report, report.hasFindings {
                Button {
                    model.copyAllFixPrompts(report.alerts)
                } label: {
                    Label("Copiar prompt geral", systemImage: "doc.on.doc")
                }
                .buttonStyle(ModalSurfaceButtonStyle())
                .help("Copia um único prompt para corrigir todos os projetos afetados, inclusive os filtrados")
                .disabled(!model.canScan)
            }

            Button {
                model.scan()
            } label: {
                Label("Verificar agora", systemImage: "arrow.clockwise")
            }
            .buttonStyle(ModalLimeButtonStyle())
            .disabled(!model.canScan)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private func filterBar(_ report: ScanReport) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CBTheme.textTertiary)

                TextField("Buscar projeto, pacote ou caminho", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.text)

                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(width: 300)

            HStack(spacing: 6) {
                ForEach(RiskFilter.allCases) { filter in
                    filterChip(filter)
                }
            }

            if report.alerts.contains(where: \.hasKEV) {
                filterChip(title: "KEV", tint: CBTheme.critical, selected: onlyKEV) {
                    onlyKEV.toggle()
                }
            }

            Spacer(minLength: 8)

            Text("\(filteredAlerts(report).count) de \(report.alerts.count) projetos")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
    }

    private func filterChip(_ filter: RiskFilter) -> some View {
        filterChip(
            title: filter.title,
            tint: filter.tint,
            selected: riskFilter == filter
        ) {
            riskFilter = filter
        }
    }

    private func filterChip(
        title: String,
        tint: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .medium : .regular, design: .rounded))
                .foregroundStyle(selected ? tint : CBTheme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    selected ? tint.opacity(0.13) : CBTheme.surface,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if model.isScanning {
            ScanProgressCard(progress: model.scanProgress)
            scanHint
                .padding(.top, 14)
        } else if let error = model.scanError {
            NoticeCard(
                kind: .error,
                title: "A varredura não terminou",
                message: error,
                actionTitle: "Tentar de novo",
                action: { model.scan() }
            )
            if let report = model.report {
                reportContent(report)
                    .padding(.top, 22)
            }
        } else if let report = model.report {
            reportContent(report)
        } else {
            EmptyPanelCard(
                symbol: "shield.lefthalf.filled",
                title: "Pronto para a primeira varredura",
                message: "O Builders Protect lê seus lockfiles, compara com a base de vulnerabilidades e explica o que corrigir.",
                actionTitle: "Verificar agora",
                action: { model.scan() }
            )
        }
    }

    private func reportContent(_ report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            summaryCard(report)

            if !report.warnings.isEmpty {
                warningsCard(report)
            }

            if report.hasFindings {
                projectsSection(report)
            } else {
                cleanState(report)
            }

            if !report.nextSteps.isEmpty {
                nextSteps(report)
            }
        }
    }

    private func summaryCard(_ report: ScanReport) -> some View {
        let risk = report.hasFindings ? report.risk : .low

        return HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    SectionLabel(text: report.hasFindings ? "Resultado da análise" : "Tudo limpo")
                    if report.llmUsed {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("análise da IA")
                        }
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.limeMuted, in: Capsule())
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(report.hasFindings ? report.alerts.count : report.projectsScanned)")
                        .font(.system(size: 60, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(CBTheme.text)
                    Text(report.hasFindings ? "projetos afetados" : "projetos verificados")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                }

                Text(Vocabulary.prose(report.summary))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 34) {
                    inlineStat(value: "\(report.projectsScanned)", label: "Projetos")
                    inlineStat(value: "\(report.lockfilesChecked)", label: "Lockfiles")
                    inlineStat(value: "\(report.totalPackages)", label: "Pacotes")
                    Spacer()
                    Label(model.lastScanLabel, systemImage: "clock")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }
                .padding(.top, 2)
            }

            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill((report.hasFindings ? risk.color : CBTheme.mint).opacity(0.10))
                    Circle()
                        .stroke(
                            (report.hasFindings ? risk.color : CBTheme.mint).opacity(0.28),
                            lineWidth: 1
                        )
                    Image(systemName: report.hasFindings ? risk.symbol : "checkmark.shield.fill")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(report.hasFindings ? risk.color : CBTheme.mint)
                }
                .frame(width: 76, height: 76)

                Text(report.hasFindings ? risk.shortLabel : "LIMPO")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(report.hasFindings ? risk.color : CBTheme.mint)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(CBTheme.surface)
                LinearGradient(
                    colors: [
                        (report.hasFindings ? report.risk.color : CBTheme.mint).opacity(0.06),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        )
    }

    private func inlineStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 21, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(CBTheme.text)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundStyle(CBTheme.textTertiary)
        }
    }

    private func warningsCard(_ report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Avisos da varredura")
            ForEach(Array(report.warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(CBTheme.medium)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(Vocabulary.clean(warning))
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func projectsSection(_ report: ScanReport) -> some View {
        let alerts = filteredAlerts(report)

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Projetos afetados")
                Spacer()
                Text("\(alerts.count) de \(report.alerts.count)")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .monospacedDigit()
            }

            if alerts.isEmpty {
                emptyFilterState
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(alerts) { alert in
                        AnalysisProjectRow(
                            alert: alert,
                            expanded: expandedID == alert.id,
                            onToggle: {
                                expandedID = expandedID == alert.id ? nil : alert.id
                            },
                            onCopy: { model.copyFixPrompt(alert) },
                            onDetails: { model.openAlert(alert) },
                            onExclude: { exclusionCandidate = alert },
                            onOpenFolder: { model.openProjectFolder(alert) }
                        )
                    }
                }
            }
        }
    }

    private var emptyFilterState: some View {
        HStack(spacing: 13) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(CBTheme.textTertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Nenhum projeto com esses filtros")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("Tente outro termo ou remova os filtros.")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            Button {
                search = ""
                riskFilter = .all
                onlyKEV = false
            } label: {
                Text("Limpar filtros")
            }
            .buttonStyle(ModalSurfaceButtonStyle())
        }
        .padding(18)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func filteredAlerts(_ report: ScanReport) -> [ProjectAlert] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)

        return report.alerts.filter { alert in
            if let risk = riskFilter.risk, alert.risk != risk {
                return false
            }
            if onlyKEV && !alert.hasKEV {
                return false
            }
            guard !query.isEmpty else { return true }

            if alert.project.name.localizedCaseInsensitiveContains(query) { return true }
            if alert.project.path.localizedCaseInsensitiveContains(query) { return true }
            if alert.headline.localizedCaseInsensitiveContains(query) { return true }
            return alert.packageAggregates.contains {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private func cleanState(_ report: ScanReport) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(CBTheme.mint)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nenhuma vulnerabilidade conhecida nas versões instaladas")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("\(Vocabulary.quantity(report.projectsScanned, "projeto", "projetos")) e \(Vocabulary.quantity(report.lockfilesChecked, "lockfile", "lockfiles")) verificados.")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            Spacer()
        }
        .padding(20)
        .background(CBTheme.mint.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func nextSteps(_ report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(text: "Próximos passos")
            ForEach(Array(report.nextSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 11) {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CBTheme.lime)
                        .frame(width: 20, height: 20)
                        .background(CBTheme.limeMuted, in: Circle())
                    Text(Vocabulary.prose(step))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var scanHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(CBTheme.lime)
                .padding(.top, 1)
            Text("A varredura de dependências envia apenas nomes, versões e lockfiles. O Pest tem consentimento próprio para código.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("As análises ficam salvas neste Mac.")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)

            Spacer()

            Button {
                model.settingsSection = .account
            } label: {
                Label("Ajustes", systemImage: "gearshape")
            }
            .buttonStyle(ModalGhostButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
    }

    private var statusColor: Color {
        if model.isScanning { return CBTheme.lime }
        if model.authStatus.connected { return CBTheme.mint }
        return CBTheme.high
    }

    private var statusLabel: String {
        if model.isScanning { return "Verificando" }
        return model.authLabel
    }
}

private enum RiskFilter: String, CaseIterable, Identifiable {
    case all
    case critical
    case high
    case medium
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todos"
        case .critical: return "Crítica"
        case .high: return "Alta"
        case .medium: return "Média"
        case .low: return "Baixa"
        }
    }

    var risk: RiskLevel? {
        switch self {
        case .all: return nil
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    var tint: Color {
        risk?.color ?? CBTheme.lime
    }
}

private struct AnalysisProjectRow: View {
    let alert: ProjectAlert
    let expanded: Bool
    let onCopy: () -> Void
    let onDetails: () -> Void
    let onExclude: () -> Void
    let onOpenFolder: () -> Void
    let onToggle: () -> Void

    init(
        alert: ProjectAlert,
        expanded: Bool,
        onToggle: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onDetails: @escaping () -> Void,
        onExclude: @escaping () -> Void,
        onOpenFolder: @escaping () -> Void
    ) {
        self.alert = alert
        self.expanded = expanded
        self.onToggle = onToggle
        self.onCopy = onCopy
        self.onDetails = onDetails
        self.onExclude = onExclude
        self.onOpenFolder = onOpenFolder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 16) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(alert.risk.color)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 8) {
                            RiskBadge(risk: alert.risk)
                            if alert.hasKEV { KEVBadge() }
                            Spacer(minLength: 8)
                            if alert.llmUsed {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(CBTheme.lime)
                            }
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(CBTheme.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.project.name)
                                .font(.system(size: 19, weight: .light, design: .rounded))
                                .foregroundStyle(CBTheme.text)
                                .lineLimit(1)
                            Text(alert.project.path.homeAbbreviated)
                                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Text(Vocabulary.headline(alert.headline))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)

                        HStack(spacing: 15) {
                            Label("Vulnerabilidades", systemImage: "shield.lefthalf.filled")
                            Label(Vocabulary.quantity(alert.packageCount, "pacote", "pacotes"), systemImage: "shippingbox")
                        }
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                    }
                    .padding(.leading, 14)
                    .padding(.vertical, 18)
                    .padding(.trailing, 18)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !expanded {
                HStack(spacing: 8) {
                    ForEach(Array(alert.packageAggregates.prefix(3))) { package in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(package.severity.color)
                                .frame(width: 4, height: 4)
                            Text(package.name)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    if alert.packageCount > 3 {
                        Text("+\(alert.packageCount - 3)")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.leading, 17)
                .padding(.bottom, 14)
            }

            if expanded {
                Divider()
                    .overlay(CBTheme.hairline)
                    .padding(.leading, 17)

                VStack(alignment: .leading, spacing: 20) {
                    proseSection(title: "Diagnóstico", text: alert.diagnosis)
                    proseSection(title: "O que fazer", text: alert.recommendation)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            SectionLabel(text: "Pacotes afetados")
                            Spacer()
                            Text("\(alert.packageCount)")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                        }
                        ForEach(Array(alert.packageAggregates.prefix(6))) { package in
                            AnalysisPackageRow(package: package)
                        }
                        if alert.packageCount > 6 {
                            Text("+ \(Vocabulary.quantity(alert.packageCount - 6, "pacote", "pacotes")) no detalhe completo")
                                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                .foregroundStyle(CBTheme.textTertiary)
                                .padding(.top, 3)
                        }
                    }

                    HStack(spacing: 9) {
                        Button(action: onCopy) {
                            Label("Copiar prompt", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(ModalLimeButtonStyle())

                        Button(action: onDetails) {
                            Text("Abrir detalhes")
                        }
                        .buttonStyle(ModalSurfaceButtonStyle())

                        Button(action: onExclude) {
                            Label("Ignorar pasta", systemImage: "eye.slash")
                        }
                        .buttonStyle(ModalSurfaceButtonStyle())

                        Spacer(minLength: 0)

                        Button(action: onOpenFolder) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(IconButtonStyle(size: 34))
                        .help("Abrir pasta no Finder")
                    }
                }
                .padding(.leading, 17)
                .padding(.trailing, 18)
                .padding(.vertical, 20)
            }
        }
        .background(
            CBTheme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .contextMenu {
            Button(role: .destructive, action: onExclude) {
                Label("Ignorar pasta", systemImage: "eye.slash")
            }
            Button(action: onOpenFolder) {
                Label("Abrir pasta no Finder", systemImage: "folder")
            }
        }
    }

    private func proseSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: title)
            Text(Vocabulary.prose(text))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct AnalysisPackageRow: View {
    let package: PackageAggregate

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(package.severity.color)
                .frame(width: 5, height: 5)

            Text(package.name)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(CBTheme.text)
                .lineLimit(1)

            Text(package.installedVersion)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(CBTheme.textTertiary)
                .lineLimit(1)

            if let fixed = package.fixedVersion {
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(CBTheme.textTertiary)
                Text(fixed)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(CBTheme.mint)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if package.hasKEV {
                KEVBadge()
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct ModalLimeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(CBTheme.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [CBTheme.lime, CBTheme.limeDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct ModalSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .regular, design: .rounded))
            .foregroundStyle(CBTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                CBTheme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct ModalGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(CBTheme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                configuration.isPressed ? CBTheme.surfaceStrong : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}
