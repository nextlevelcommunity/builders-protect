import CVECore
import SwiftUI

struct NetworkView: View {
    @ObservedObject var model: AppModel

    @State private var consent = false
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    consentCard
                    actionCard
                    if let report = model.latestNetworkReport {
                        reportContent(report)
                    } else if !model.isNetworkRunning {
                        emptyState
                    }
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
                    Text(L10n.t("Minha rede"))
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text(L10n.t("CHECAGEM LOCAL"))
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }
                Text(L10n.t("Sua Wi-Fi, seu roteador e seus dados, sem alarmismo"))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            if let report = model.latestNetworkReport {
                Button {
                    model.copyNetworkGeneralPrompt(report)
                } label: {
                    Label(L10n.t("Prompt geral"), systemImage: "wand.and.stars")
                }
                .buttonStyle(LimeButtonStyle())

                HStack(spacing: 7) {
                    Circle()
                        .fill(report.findings.isEmpty ? CBTheme.mint : report.risk.color)
                        .frame(width: 6, height: 6)
                    Text(
                        report.findings.isEmpty
                            ? L10n.t("Sem achados", "No findings")
                            : Vocabulary.quantity(report.findings.count, "ponto", "pontos")
                    )
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CBTheme.surface, in: Capsule())
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Uma foto da rede, não uma prova de invasão"))
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("O Builders Protect lê as configurações que o macOS mostra, consulta apenas o endereço do seu roteador e lista os aparelhos e serviços visíveis. Ele não captura tráfego, não testa senhas, não entra no painel do roteador e não consegue provar que alguém invadiu sua rede. O objetivo é explicar o que está exposto e o que vale corrigir primeiro."))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            CBTheme.lime.opacity(0.045),
            in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
        )
    }

    private var consentCard: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: L10n.t("Antes de verificar"))

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("Autorizo uma consulta local à minha rede"))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("A checagem usa comandos do macOS, consulta o endereço do roteador por HTTP/HTTPS e não envia dados da rede para a Cultura Builder. Nenhuma senha é testada. Nenhum tráfego é gravado."))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle(isOn: $consent) {
                    Text(L10n.t("Entendi e autorizo esta checagem local."))
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                }
                .toggleStyle(.checkbox)
                .disabled(model.isNetworkRunning)

                Divider().overlay(CBTheme.hairline)

                Toggle(isOn: $model.networkIsPublic) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.t("Estou numa rede pública"))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("Hotel, aeroporto, café, coworking ou uma rede que você não controla. Isso torna os cenários de confiança mais rigorosos."))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .tint(CBTheme.lime)
                .controlSize(.small)
                .disabled(model.isNetworkRunning)
            }
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isNetworkRunning {
                ScanProgressCard(
                    progress: model.networkProgress.map {
                        ScanProgress(phase: $0.phase, detail: $0.detail, fraction: $0.fraction)
                    }
                )

                Button {
                    model.cancelNetworkAnalysis()
                } label: {
                    Label(L10n.t("Cancelar checagem"), systemImage: "xmark")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
            } else {
                Button {
                    consent = false
                    model.startNetworkAnalysis()
                } label: {
                    Label(L10n.t("Analisar minha rede"), systemImage: "wifi")
                }
                .buttonStyle(LimeButtonStyle(fullWidth: true))
                .disabled(!canStart)

                Text(
                    consent
                        ? L10n.t("A checagem leva alguns segundos. Você pode continuar usando o Mac.", "The check takes a few seconds. You can keep using the Mac.")
                        : L10n.t("Marque a autorização acima para liberar a checagem.", "Check the authorization above to enable the check.")
                )
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            }

            if let error = model.networkError {
                NoticeCard(kind: .error, title: L10n.t("A checagem não terminou"), message: error)
            }
        }
    }

    private var canStart: Bool {
        model.canRunNetwork && consent
    }

    private var emptyState: some View {
        NoticeCard(
            kind: .info,
            title: L10n.t("Ainda não verificado"),
            message: L10n.t("Faça a primeira leitura para ver a proteção da Wi-Fi, o estado do roteador e os serviços do Mac visíveis para a rede. Nenhuma alteração será feita.")
        )
    }

    @ViewBuilder
    private func reportContent(_ report: NetworkReport) -> some View {
        reportHeader(report)
        scenarioSection(report)
        findingsSection(report)
        technicalDetails(report)
        limitations(report.limitations)
    }

    private func reportHeader(_ report: NetworkReport) -> some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            SectionLabel(text: L10n.t("Última checagem"))
                            if !report.findings.isEmpty {
                                RiskBadge(risk: report.risk, compact: true)
                            }
                        }
                        Text(report.snapshot.ssid ?? L10n.t("Sua Wi-Fi", "Your Wi-Fi"))
                            .font(.system(size: 20, weight: .light, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("\(report.finishedAt.relativeShort) · \(L10n.t(report.snapshot.securityLabel))")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(report.findings.count)")
                            .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(
                                report.findings.isEmpty ? CBTheme.mint : report.risk.color
                            )
                        Text(report.findings.isEmpty
                            ? L10n.t("SEM ACHADOS", "NO FINDINGS")
                            : (report.findings.count == 1 ? L10n.t("PONTO", "POINT") : L10n.t("PONTOS", "POINTS")))
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                }

                Text(Vocabulary.prose(report.summary))
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 22) {
                    networkMetric(
                        L10n.t("Roteador", "Router"),
                        report.snapshot.gateway ?? L10n.t("não identificado", "not identified")
                    )
                    networkMetric(
                        L10n.t("Dispositivos", "Devices"),
                        "\(report.snapshot.devices.count)"
                    )
                    networkMetric(
                        L10n.t("Serviços expostos", "Exposed services"),
                        "\(report.exposedServices.count)"
                    )
                    networkMetric(
                        "VPN",
                        report.snapshot.vpnActive
                            ? L10n.t("ativa", "active")
                            : L10n.t("não detectada", "not detected")
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        model.copyNetworkGeneralPrompt(report)
                    } label: {
                        Label(L10n.t("Copiar prompt geral"), systemImage: "wand.and.stars")
                    }
                    .buttonStyle(LimeButtonStyle())

                    Button {
                        model.copyNetworkSummary(report)
                    } label: {
                        Label(L10n.t("Copiar resumo"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))

                    Spacer()

                    Text(report.context.isPublicNetwork
                        ? L10n.t("rede marcada como pública", "network marked as public")
                        : L10n.t("rede tratada como confiável", "network treated as trusted"))
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }
            }
        }
    }

    private func networkMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(CBTheme.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scenarioSection(_ report: NetworkReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: L10n.t("O que pode acontecer"))
            Text(L10n.t("Cada cenário mostra o que foi confirmado agora, o que é possível no seu tipo de rede e o que não foi possível verificar."))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(report.scenarios) { scenario in
                NetworkScenarioCard(scenario: scenario)
            }
        }
    }

    @ViewBuilder
    private func findingsSection(_ report: NetworkReport) -> some View {
        if report.findings.isEmpty {
            NoticeCard(
                kind: .success,
                title: L10n.t("Nenhum ponto de atenção visível"),
                message: L10n.t("Não encontrei falha grave nas configurações que consegui verificar. Isso não prova que a rede é invulnerável, mas não há nada urgente para corrigir nesta foto.")
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: L10n.t("Pontos de atenção"))
                ForEach(report.findings) { finding in
                    NetworkFindingCard(finding: finding) {
                        model.copyNetworkFixPrompt(finding)
                    }
                }
            }
        }
    }

    private func technicalDetails(_ report: NetworkReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showDetails.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    SectionLabel(text: L10n.t("Detalhes técnicos"))
                    Spacer()
                    Text(showDetails
                        ? L10n.t("Ocultar", "Hide")
                        : L10n.t("Mostrar", "Show"))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(CBTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showDetails {
                SurfaceCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow("Wi-Fi", report.snapshot.ssid ?? L10n.t("não identificada", "not identified"))
                        detailRow(L10n.t("Proteção", "Protection"), L10n.t(report.snapshot.securityLabel))
                        detailRow(L10n.t("Interface", "Interface"), report.snapshot.interfaceName ?? L10n.t("não identificada", "not identified"))
                        detailRow(L10n.t("Canal", "Channel"), report.snapshot.channel ?? L10n.t("não informado", "not provided"))
                        detailRow(L10n.t("Sinal", "Signal"), report.snapshot.signal ?? L10n.t("não informado", "not provided"))
                        detailRow("Gateway", report.snapshot.gateway ?? L10n.t("não identificado", "not identified"))
                        detailRow("DNS", report.snapshot.dnsServers.joined(separator: ", "))
                        detailRow("Host", report.snapshot.hostName)
                        if !report.snapshot.vpnInterfaces.isEmpty {
                            detailRow(L10n.t("Interfaces VPN", "VPN interfaces"), report.snapshot.vpnInterfaces.joined(separator: ", "))
                        }

                        if !report.snapshot.devices.isEmpty {
                            Divider().overlay(CBTheme.hairline)
                            ForEach(report.snapshot.devices) { device in
                                detailRow(
                                    device.isGateway ? L10n.t("Roteador", "Router") : device.macKind,
                                    "\(device.ip) · \(device.mac)"
                                )
                            }
                        }

                        if !report.snapshot.listeningServices.isEmpty {
                            Divider().overlay(CBTheme.hairline)
                            ForEach(report.snapshot.listeningServices) { service in
                                detailRow(
                                    service.exposedToLAN
                                        ? L10n.t("Serviço exposto", "Exposed service")
                                        : L10n.t("Serviço local", "Local service"),
                                    "\(service.process) · \(service.bind):\(service.port)"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .frame(width: 118, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .foregroundStyle(CBTheme.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
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
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L10n.t("Minha rede: leitura local. Não captura tráfego, não testa senhas e não prova invasão."))
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            Spacer()
            Button {
                model.settingsSection = .routine
            } label: {
                Label(L10n.t("Notificações"), systemImage: "bell")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
    }
}

private struct NetworkScenarioCard: View {
    let scenario: NetworkScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 19, height: 19)
                    .background(color.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(Vocabulary.prose(scenario.title))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t(scenario.status.label).uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(color)
                }
                Spacer(minLength: 0)
            }

            Text(Vocabulary.prose(scenario.explanation))
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            if !scenario.whatCouldHappen.isEmpty {
                scenarioLabel(L10n.t("O que poderia acontecer", "What could happen"), scenario.whatCouldHappen)
            }
            if !scenario.protection.isEmpty {
                scenarioLabel(L10n.t("Como se proteger", "How to protect yourself"), scenario.protection)
            }

            Text(Vocabulary.prose(scenario.basedOn))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            CBTheme.surface,
            in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
        )
    }

    private func scenarioLabel(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(CBTheme.textTertiary)
            Text(Vocabulary.prose(text))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var color: Color {
        switch scenario.status {
        case .confirmed: return CBTheme.critical
        case .possible: return CBTheme.high
        case .notFound: return CBTheme.mint
        case .unverified: return CBTheme.unknown
        }
    }

    private var symbol: String {
        switch scenario.status {
        case .confirmed: return "exclamationmark.triangle.fill"
        case .possible: return "exclamationmark.circle.fill"
        case .notFound: return "checkmark.circle.fill"
        case .unverified: return "questionmark.circle.fill"
        }
    }
}

private struct NetworkFindingCard: View {
    let finding: NetworkFinding
    let onCopyPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        RiskBadge(risk: finding.severity, compact: true)
                        Text(L10n.t(finding.category).uppercased())
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    Text(Vocabulary.prose(finding.title))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(finding.target)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }

            if !finding.evidence.isEmpty {
                Text(finding.evidence)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
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

            labeledText(L10n.t("O que significa", "What it means"), finding.whatItMeans)
            labeledText(L10n.t("No seu cenário", "In your scenario"), finding.scenario)
            labeledText(L10n.t("Chance", "Likelihood"), finding.likelihood)
            labeledText(L10n.t("Como corrigir", "How to fix"), finding.recommendation)

            Button {
                onCopyPrompt()
            } label: {
                Label(L10n.t("Copiar prompt de correção"), systemImage: "doc.on.doc.fill")
            }
            .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))
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
            Text(Vocabulary.prose(text))
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
