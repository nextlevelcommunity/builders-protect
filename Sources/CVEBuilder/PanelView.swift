import CVECore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                Rectangle()
                    .fill(CBTheme.hairline)
                    .frame(height: 1)
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .padding(16)
                }
                Rectangle()
                    .fill(CBTheme.hairline)
                    .frame(height: 1)
                footer
            }

            if let toast = model.toast {
                ToastView(message: toast)
                    .padding(.bottom, 13)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 440, height: 700)
        .background(panelBackground)
        .preferredColorScheme(.dark)
        .onAppear {
            model.panelOpened()
        }
        .animation(.easeInOut(duration: 0.22), value: model.toast)
    }

    private var panelBackground: some View {
        ZStack {
            CBTheme.background
            RadialGradient(
                colors: [CBTheme.lime.opacity(0.065), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 35)

            VStack(alignment: .leading, spacing: 1) {
                BrandWordmark(compact: true)
                Text("Vulnerabilidades sob controle")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                Text(statusLabel)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(CBTheme.surface, in: Capsule())

            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle(size: 28))
            .help("Ajustes")

            Button {
                model.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(IconButtonStyle(size: 28))
            .help("Sair do Builders Protect")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            if !model.settings.hasCompletedOnboarding {
                EmptyPanelCard(
                    symbol: "slider.horizontal.3",
                    title: "Vamos configurar o Builders Protect",
                    message: "Escolha suas pastas, conecte a conta da Cultura Builder e defina a rotina diária.",
                    actionTitle: "Retomar configuração",
                    action: { model.openOnboarding() }
                )
            } else if model.settings.folders.isEmpty {
                EmptyPanelCard(
                    symbol: "folder.badge.plus",
                    title: "Nenhuma pasta monitorada",
                    message: "Adicione as pastas onde ficam seus projetos para começar a verificar as dependências.",
                    actionTitle: "Abrir ajustes",
                    action: { model.openSettings() }
                )
            } else if model.isScanning {
                ScanProgressCard(progress: model.scanProgress)
                scanHint
            } else if let error = model.scanError {
                NoticeCard(
                    kind: .error,
                    title: "A varredura não terminou",
                    message: error,
                    actionTitle: "Tentar de novo",
                    action: { model.scan() }
                )
                if let report = model.report {
                    summaryHero(report: report)
                    openAnalysisButton(report: report)
                }
            } else if let report = model.report {
                summaryHero(report: report)

                if !model.authStatus.connected {
                    AuthMiniCard(model: model)
                }

                openAnalysisButton(report: report)

                if report.hasFindings {
                    quickRisks(report: report)
                }
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
    }

    private var scanHint: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "lock.shield")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
                .padding(.top, 1)
            Text("Apenas nomes, versões e lockfiles saem deste Mac. Nenhum código-fonte.")
                .font(.system(size: 9.2, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private func summaryHero(report: ScanReport) -> some View {
        let risk = report.hasFindings ? report.risk : .low
        let hasFindings = report.hasFindings

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        SectionLabel(text: hasFindings ? "Situação atual" : "Tudo limpo")
                        if report.llmUsed {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                Text("análise da IA")
                            }
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .foregroundStyle(CBTheme.lime)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(CBTheme.limeMuted, in: Capsule())
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(hasFindings ? report.alerts.count : report.projectsScanned)")
                            .font(.system(size: 46, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(CBTheme.text)
                        Text(hasFindings ? "projetos afetados" : "projetos verificados")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                    }

                    Text(Vocabulary.prose(report.summary))
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .lineSpacing(1.5)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)

                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill((hasFindings ? risk.color : CBTheme.mint).opacity(0.10))
                        Circle()
                            .stroke(
                                (hasFindings ? risk.color : CBTheme.mint).opacity(0.28),
                                lineWidth: 1
                            )
                        Image(systemName: hasFindings ? risk.symbol : "checkmark.shield.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(hasFindings ? risk.color : CBTheme.mint)
                    }
                    .frame(width: 56, height: 56)

                    Text(hasFindings ? risk.shortLabel : "LIMPO")
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(hasFindings ? risk.color : CBTheme.mint)
                }
            }

            HStack(spacing: 0) {
                CounterTile(
                    value: "\(report.projectsScanned)",
                    label: "Projetos",
                    tint: CBTheme.text
                )
                verticalDivider
                CounterTile(
                    value: "\(report.totalPackages)",
                    label: "Pacotes",
                    tint: CBTheme.text
                )
            }

            Divider().overlay(CBTheme.hairline)

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(CBTheme.textTertiary)
                Text(model.lastScanLabel)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)

                Spacer(minLength: 6)

                Button {
                    model.scan()
                } label: {
                    Label("Verificar agora", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.lime))
                .disabled(!model.canScan)
            }
        }
        .padding(15)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CBTheme.surface)
                LinearGradient(
                    colors: [
                        (hasFindings ? risk.color : CBTheme.mint).opacity(0.075),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(CBTheme.hairline)
            .frame(width: 1, height: 29)
            .padding(.horizontal, 12)
    }

    private func openAnalysisButton(report: ScanReport) -> some View {
        Button {
            model.openReport()
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(CBTheme.limeMuted)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Abrir análise completa")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text(analysisSubtitle(report))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CBTheme.textTertiary)
            }
            .padding(11)
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func analysisSubtitle(_ report: ScanReport) -> String {
        var parts = [
            Vocabulary.quantity(report.alerts.count, "projeto", "projetos"),
            Vocabulary.quantity(report.totalPackages, "pacote", "pacotes")
        ]
        if !report.warnings.isEmpty {
            parts.append(Vocabulary.quantity(report.warnings.count, "aviso", "avisos"))
        }
        return parts.joined(separator: " · ")
    }

    private func quickRisks(report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Principais riscos")
                .padding(.horizontal, 2)

            ForEach(Array(report.alerts.prefix(3))) { alert in
                Button {
                    model.openAlert(alert)
                } label: {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(alert.risk.color)
                            .frame(width: 6, height: 6)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(alert.project.name)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(CBTheme.text)
                                .lineLimit(1)
                            Text(Vocabulary.quantity(alert.packageCount, "pacote", "pacotes"))
                                .font(.system(size: 8.5, weight: .regular, design: .rounded))
                                .foregroundStyle(CBTheme.textTertiary)
                        }

                        Spacer(minLength: 4)

                        RiskBadge(risk: alert.risk, compact: true)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                model.openSettings()
            } label: {
                Label("Ajustes", systemImage: "gearshape")
            }
            .buttonStyle(GhostButtonStyle())

            Button {
                model.openOnboarding()
            } label: {
                Text("Guia")
            }
            .buttonStyle(GhostButtonStyle())

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 8, weight: .semibold))
                Text(model.nextRunLabel)
            }
            .font(.system(size: 8.5, weight: .medium, design: .rounded))
            .foregroundStyle(CBTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
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
