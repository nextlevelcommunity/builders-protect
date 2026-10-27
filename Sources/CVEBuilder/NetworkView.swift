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
                    Text("Minha rede")
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text("CHECAGEM LOCAL")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(CBTheme.lime)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CBTheme.lime.opacity(0.1), in: Capsule())
                }
                Text("Sua Wi-Fi, seu roteador e seus dados, sem alarmismo")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            if let report = model.latestNetworkReport {
                Button {
                    model.copyNetworkGeneralPrompt(report)
                } label: {
                    Label("Prompt geral", systemImage: "wand.and.stars")
                }
                .buttonStyle(LimeButtonStyle())

                HStack(spacing: 7) {
                    Circle()
                        .fill(report.findings.isEmpty ? CBTheme.mint : report.risk.color)
                        .frame(width: 6, height: 6)
                    Text(
                        report.findings.isEmpty
                            ? "Sem achados"
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
                Text("Uma foto da rede, não uma prova de invasão")
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("O Builders Protect lê as configurações que o macOS mostra, consulta apenas o endereço do seu roteador e lista os aparelhos e serviços visíveis. Ele não captura tráfego, não testa senhas, não entra no painel do roteador e não consegue provar que alguém invadiu sua rede. O objetivo é explicar o que está exposto e o que vale corrigir primeiro.")
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
                SectionLabel(text: "Antes de verificar")

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Autorizo uma consulta local à minha rede")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("A checagem usa comandos do macOS, consulta o endereço do roteador por HTTP/HTTPS e não envia dados da rede para a Cultura Builder. Nenhuma senha é testada. Nenhum tráfego é gravado.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle(isOn: $consent) {
                    Text("Entendi e autorizo esta checagem local.")
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                }
                .toggleStyle(.checkbox)
                .disabled(model.isNetworkRunning)

                Divider().overlay(CBTheme.hairline)

                Toggle(isOn: $model.networkIsPublic) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Estou numa rede pública")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("Hotel, aeroporto, café, coworking ou uma rede que você não controla. Isso torna os cenários de confiança mais rigorosos.")
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
                    Label("Cancelar checagem", systemImage: "xmark")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.critical))
            } else {
                Button {
                    consent = false
                    model.startNetworkAnalysis()
                } label: {
                    Label("Analisar minha rede", systemImage: "wifi")
                }
                .buttonStyle(LimeButtonStyle(fullWidth: true))
                .disabled(!canStart)

                Text(
                    consent
                        ? "A checagem leva alguns segundos. Você pode continuar usando o Mac."
                        : "Marque a autorização acima para liberar a checagem."
                )
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            }

            if let error = model.networkError {
                NoticeCard(kind: .error, title: "A checagem não terminou", message: error)
            }
        }
    }

    private var canStart: Bool {
        model.canRunNetwork && consent
    }

    private var emptyState: some View {
        NoticeCard(
            kind: .info,
            title: "Ainda não verificado",
            message: "Faça a primeira leitura para ver a proteção da Wi-Fi, o estado do roteador e os serviços do Mac visíveis para a rede. Nenhuma alteração será feita."
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
                            SectionLabel(text: "Última checagem")
                            if !report.findings.isEmpty {
                                RiskBadge(risk: report.risk, compact: true)
                            }
                        }
                        Text(report.snapshot.ssid ?? "Sua Wi-Fi")
                            .font(.system(size: 20, weight: .light, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text("\(report.finishedAt.relativeShort) · \(report.snapshot.securityLabel)")
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
                        Text(report.findings.isEmpty ? "SEM ACHADOS" : (report.findings.count == 1 ? "PONTO" : "PONTOS"))
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
                        "Roteador",
                        report.snapshot.gateway ?? "não identificado"
                    )
                    networkMetric(
                        "Dispositivos",
                        "\(report.snapshot.devices.count)"
                    )
                    networkMetric(
                        "Serviços expostos",
                        "\(report.exposedServices.count)"
                    )
                    networkMetric(
                        "VPN",
                        report.snapshot.vpnActive ? "ativa" : "não detectada"
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        model.copyNetworkGeneralPrompt(report)
                    } label: {
                        Label("Copiar prompt geral", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(LimeButtonStyle())

                    Button {
                        model.copyNetworkSummary(report)
                    } label: {
                        Label("Copiar resumo", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))

                    Spacer()

                    Text(report.context.isPublicNetwork ? "rede marcada como pública" : "rede tratada como confiável")
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
            SectionLabel(text: "O que pode acontecer")
            Text("Cada cenário mostra o que foi confirmado agora, o que é possível no seu tipo de rede e o que não foi possível verificar.")
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
                title: "Nenhum ponto de atenção visível",
                message: "Não encontrei falha grave nas configurações que consegui verificar. Isso não prova que a rede é invulnerável, mas não há nada urgente para corrigir nesta foto."
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Pontos de atenção")
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
                    SectionLabel(text: "Detalhes técnicos")
                    Spacer()
                    Text(showDetails ? "Ocultar" : "Mostrar")
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
                        detailRow("Wi-Fi", report.snapshot.ssid ?? "não identificada")
                        detailRow("Proteção", report.snapshot.securityLabel)
                        detailRow("Interface", report.snapshot.interfaceName ?? "não identificada")
                        detailRow("Canal", report.snapshot.channel ?? "não informado")
                        detailRow("Sinal", report.snapshot.signal ?? "não informado")
                        detailRow("Gateway", report.snapshot.gateway ?? "não identificado")
                        detailRow("DNS", report.snapshot.dnsServers.joined(separator: ", "))
                        detailRow("Host", report.snapshot.hostName)
                        if !report.snapshot.vpnInterfaces.isEmpty {
                            detailRow("Interfaces VPN", report.snapshot.vpnInterfaces.joined(separator: ", "))
                        }

                        if !report.snapshot.devices.isEmpty {
                            Divider().overlay(CBTheme.hairline)
                            ForEach(report.snapshot.devices) { device in
                                detailRow(
                                    device.isGateway ? "Roteador" : device.macKind,
                                    "\(device.ip) · \(device.mac)"
                                )
                            }
                        }

                        if !report.snapshot.listeningServices.isEmpty {
                            Divider().overlay(CBTheme.hairline)
                            ForEach(report.snapshot.listeningServices) { service in
                                detailRow(
                                    service.exposedToLAN ? "Serviço exposto" : "Serviço local",
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
            SectionLabel(text: "Limites desta análise")
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
            Text("Minha rede: leitura local. Não captura tráfego, não testa senhas e não prova invasão.")
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            Spacer()
            Button {
                model.settingsSection = .routine
            } label: {
                Label("Notificações", systemImage: "bell")
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
                    Text(scenario.status.label.uppercased())
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
                scenarioLabel("O que poderia acontecer", scenario.whatCouldHappen)
            }
            if !scenario.protection.isEmpty {
                scenarioLabel("Como se proteger", scenario.protection)
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
                        Text(finding.category.uppercased())
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

            labeledText("O que significa", finding.whatItMeans)
            labeledText("No seu cenário", finding.scenario)
            labeledText("Chance", finding.likelihood)
            labeledText("Como corrigir", finding.recommendation)

            Button {
                onCopyPrompt()
            } label: {
                Label("Copiar prompt de correção", systemImage: "doc.on.doc.fill")
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
