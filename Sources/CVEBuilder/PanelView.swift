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
                        .padding(18)
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
        .frame(width: 460, height: 720)
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
        HStack(spacing: 11) {
            BrandMark(size: 38)

            VStack(alignment: .leading, spacing: 2) {
                BrandWordmark(compact: true)
                Text("Vulnerabilidades sob controle")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text("IA")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(CBTheme.surface, in: Capsule())
            .help(statusHelp)

            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle(size: 30))
            .help("Ajustes")

            Button {
                model.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(IconButtonStyle(size: 30))
            .help("Sair do Builders Protect")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {
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
                    controlCenterBanner()
                }
            } else if let report = model.report {
                summaryHero(report: report)

                if !model.authStatus.connected {
                    AuthMiniCard(model: model)
                }

                controlCenterBanner()

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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
                .padding(.top, 1)
            Text("Apenas nomes, versões e lockfiles saem deste Mac. Nenhum código-fonte.")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private func summaryHero(report: ScanReport) -> some View {
        let risk = report.hasFindings ? report.risk : .low
        let hasFindings = report.hasFindings
        let count = hasFindings ? report.alerts.count : report.projectsScanned
        let accent = hasFindings ? risk.color : CBTheme.mint

        return VStack(alignment: .leading, spacing: 16) {
            Button {
                model.openReport()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            Text("\(count)")
                                .font(.system(size: 54, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(CBTheme.text)
                                .fixedSize()

                            VStack(alignment: .leading, spacing: 1) {
                                Text(count == 1 ? "projeto" : "projetos")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CBTheme.text)
                                Text(
                                    hasFindings
                                        ? (count == 1 ? "afetado" : "afetados")
                                        : (count == 1 ? "verificado" : "verificados")
                                )
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(CBTheme.textSecondary)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.10))
                                Circle()
                                    .stroke(accent.opacity(0.28), lineWidth: 1)
                                Image(systemName: hasFindings ? risk.symbol : "checkmark.shield.fill")
                                    .font(.system(size: 25, weight: .semibold))
                                    .foregroundStyle(accent)
                            }
                            .frame(width: 64, height: 64)

                            Text(hasFindings ? risk.shortLabel : "LIMPO")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(accent)
                        }
                    }

                    Text(Vocabulary.prose(report.summary))
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Abrir a central com os detalhes")

            Divider().overlay(CBTheme.hairline)

            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CBTheme.textTertiary)
                Text(model.lastScanLabel)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)

                Spacer(minLength: 8)

                Button {
                    model.openReport()
                    model.scan()
                } label: {
                    Label("Verificar agora", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.lime))
                .help("Abre a central completa e inicia uma nova verificação")
                .disabled(!model.canScan)
            }
        }
        .padding(20)
        .background(
            CBTheme.surfaceSolid,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private func controlCenterBanner() -> some View {
        Button {
            model.openReport()
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(CBTheme.surface)

                LinearGradient(
                    colors: [
                        CBTheme.lime.opacity(0.11),
                        CBTheme.mint.opacity(0.03),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONTROLE TOTAL")
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(CBTheme.lime)
                        Text("Abra a central completa")
                            .font(.system(size: 18.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("Projetos, riscos e correções em uma janela só.")
                            .font(.system(size: 11.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(CBTheme.lime)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Abrir controle total")
    }

    private func quickRisks(report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Principais riscos")
                .padding(.horizontal, 2)
                .padding(.bottom, 2)

            ForEach(Array(report.alerts.prefix(3))) { alert in
                Button {
                    model.openAlert(alert)
                } label: {
                    HStack(spacing: 11) {
                        Circle()
                            .fill(alert.risk.color)
                            .frame(width: 7, height: 7)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.project.name)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(CBTheme.text)
                                .lineLimit(1)
                            Text(Vocabulary.quantity(alert.packageCount, "pacote", "pacotes"))
                                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                .foregroundStyle(CBTheme.textTertiary)
                        }

                        Spacer(minLength: 6)

                        RiskBadge(risk: alert.risk, compact: true)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
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

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(model.nextRunLabel)
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(CBTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var statusColor: Color {
        if model.isScanning { return CBTheme.lime }
        if model.authStatus.connected { return CBTheme.mint }
        return CBTheme.high
    }

    private var statusHelp: String {
        if model.isScanning { return "Verificando dependências agora" }
        if model.authStatus.connected {
            return "IA conectada à Cultura Builder — análise inteligente ativa"
        }
        return "IA desconectada — entre na Cultura Builder em Ajustes para ativar a análise"
    }
}
