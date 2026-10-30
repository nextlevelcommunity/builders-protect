import CVECore
import SwiftUI

struct AlertDetailView: View {
    @ObservedObject var model: AppModel
    let initialAlert: ProjectAlert

    @State private var expandedPackages: Set<String>

    init(model: AppModel, alert: ProjectAlert) {
        self.model = model
        self.initialAlert = alert
        if let first = alert.packageAggregates.first {
            _expandedPackages = State(initialValue: [first.id])
        } else {
            _expandedPackages = State(initialValue: [])
        }
    }

    private var alert: ProjectAlert {
        model.report?.alerts.first { $0.id == initialAlert.id } ?? initialAlert
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                stats
                diagnosisGrid
                packagesSection
                promptSection
                footer
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 26)
        }
        .frame(minWidth: 840, minHeight: 620)
        .background(background)
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            CBTheme.background
            RadialGradient(
                colors: [alert.risk.color.opacity(0.07), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 700
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 14) {
                BrandMark(size: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("ALERTA DE SEGURANÇA"))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(CBTheme.textTertiary)

                    Text(alert.project.name)
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                        .lineLimit(1)

                    Text(alert.project.path.homeAbbreviated)
                        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        RiskBadge(risk: alert.risk)
                        if alert.hasKEV { KEVBadge() }
                    }
                    Text(L10n.t("Gerado \(alert.generatedAt.relativeShort)", "Generated \(alert.generatedAt.relativeShort)"))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                    if alert.llmUsed {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                            Text(L10n.t("análise da Cultura Builder"))
                        }
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.lime)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.copyFixPrompt(alert)
                } label: {
                    Label(L10n.t("Copiar prompt de correção"), systemImage: "doc.on.doc")
                }
                .buttonStyle(LimeButtonStyle())

                Button {
                    model.openProjectFolder(alert)
                } label: {
                    Label(L10n.t("Abrir pasta"), systemImage: "folder")
                }
                .buttonStyle(SurfaceButtonStyle())

                Button {
                    model.requestRedTeam(projectPath: alert.project.path)
                } label: {
                    Label(L10n.t("Acionar Red Team"), systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(SurfaceButtonStyle())
                .disabled(model.isRedTeamRunning)

                if let first = alert.findings.first {
                    Button {
                        model.openURL(first.url)
                    } label: {
                        Label(L10n.t("Abrir detalhes"), systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Spacer()
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            detailStat(
                "\(alert.packageCount)",
                Vocabulary.quantity(alert.packageCount, "pacote", "pacotes"),
                CBTheme.text
            )
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func detailStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(CBTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diagnosisGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            infoCard(
                label: L10n.t("Diagnóstico"),
                symbol: "stethoscope",
                text: Vocabulary.prose(alert.diagnosis),
                tint: alert.risk.color
            )
            infoCard(
                label: L10n.t("O que fazer"),
                symbol: "wrench.and.screwdriver",
                text: Vocabulary.prose(alert.recommendation),
                tint: CBTheme.lime
            )
        }
    }

    private func infoCard(
        label: String,
        symbol: String,
        text: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
                SectionLabel(text: label)
            }
            Text(text)
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var packagesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionLabel(text: L10n.t("Pacotes afetados"))
                Spacer()
                Text(Vocabulary.quantity(alert.packageCount, "pacote", "pacotes"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            ForEach(alert.packageAggregates) { package in
                PackageDetailCard(
                    package: package,
                    expanded: expandedPackages.contains(package.id),
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if expandedPackages.contains(package.id) {
                                expandedPackages.remove(package.id)
                            } else {
                                expandedPackages.insert(package.id)
                            }
                        }
                    },
                    onOpenURL: { model.openURL($0) }
                )
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionLabel(text: L10n.t("Prompt de correção"))
                Spacer()
                Button {
                    model.copyFixPrompt(alert)
                } label: {
                    Label(L10n.t("Copiar"), systemImage: "doc.on.doc")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.lime))
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(Vocabulary.prompt(alert.fixPrompt))
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2.5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
            }
            .frame(maxHeight: 250)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(L10n.t("Revise o prompt antes de aplicar. Ele foi escrito para um agente de código e não faz commit sozinho."))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L10n.t("Fonte: base de vulnerabilidades · análise: Cultura Builder"))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
            Spacer()
            Button {
                model.openProjectFolder(alert)
            } label: {
                Label(L10n.t("Abrir pasta no Finder"), systemImage: "folder")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.top, 2)
    }
}

private struct PackageDetailCard: View {
    let package: PackageAggregate
    let expanded: Bool
    let onToggle: () -> Void
    let onOpenURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(package.severity.color)
                        .frame(width: 6, height: 6)

                    Text(package.name)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CBTheme.text)

                    Text(package.installedVersion)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)

                    if let fixed = package.fixedVersion {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CBTheme.textTertiary)
                        Text(fixed)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(CBTheme.mint)
                    }

                    Spacer(minLength: 6)

                    if package.hasKEV { KEVBadge() }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CBTheme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().overlay(CBTheme.hairline)
                VStack(spacing: 0) {
                    ForEach(package.findings) { finding in
                        FindingRow(finding: finding, onOpenURL: onOpenURL)
                        if finding.id != package.findings.last?.id {
                            Divider().overlay(CBTheme.hairline)
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 4)
            }
        }
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FindingRow: View {
    let finding: DependencyFinding
    let onOpenURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Text(L10n.t("Vulnerabilidade"))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(finding.severity.color)

                if finding.isKEV { KEVBadge() }

                Spacer(minLength: 4)

                if let fixed = finding.fixedVersion {
                    Text(L10n.t("corrigido em \(fixed)", "fixed in \(fixed)"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(CBTheme.mint)
                }

                Button {
                    onOpenURL(finding.url)
                } label: {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .buttonStyle(IconButtonStyle(size: 21))
                .help(L10n.t("Abrir detalhes da vulnerabilidade"))
            }

            Text(Vocabulary.prose(finding.title))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CBTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let summary = finding.summary, !summary.isEmpty {
                Text(Vocabulary.prose(summary))
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 9)
    }
}
