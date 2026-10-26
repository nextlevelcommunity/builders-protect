import CVECore
import SwiftUI

struct RiskBadge: View {
    let risk: RiskLevel
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: risk.symbol)
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            Text(compact ? risk.label : risk.label.uppercased())
                .font(.system(size: compact ? 8.5 : 8.5, weight: .bold, design: .rounded))
                .tracking(compact ? 0 : 0.5)
        }
        .foregroundStyle(risk.color)
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, 3)
        .background(risk.color.opacity(0.12), in: Capsule())
    }
}

struct KEVBadge: View {
    var body: some View {
        Text("KEV")
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(CBTheme.critical)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(CBTheme.critical.opacity(0.14), in: Capsule())
    }
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 14
    var background: Color = CBTheme.surface
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
            )
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(CBTheme.textTertiary)
    }
}

struct CounterTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 21, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(CBTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScanProgressCard: View {
    let progress: ScanProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                    .tint(CBTheme.lime)
                VStack(alignment: .leading, spacing: 2) {
                    Text(progress?.phase ?? "Verificando dependências")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text(progress?.detail ?? "Preparando a varredura…")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [CBTheme.limeDeep, CBTheme.lime],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width
                                * min(1, max(0.035, progress?.fraction ?? 0.035))
                        )
                        .animation(.easeInOut(duration: 0.35), value: progress?.fraction)
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(
            CBTheme.lime.opacity(0.045),
            in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
        )
    }
}

struct NoticeCard: View {
    enum Kind {
        case info
        case success
        case warning
        case error

        var color: Color {
            switch self {
            case .info: return CBTheme.low
            case .success: return CBTheme.mint
            case .warning: return CBTheme.high
            case .error: return CBTheme.critical
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }
    }

    let kind: Kind
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: kind.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(kind.color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(message)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(GhostButtonStyle(tint: kind.color))
                        .padding(.top, 2)
                        .padding(.leading, -10)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            kind.color.opacity(0.065),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

struct AuthMiniCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CBTheme.high.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CBTheme.high)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Diagnóstico da IA desligado")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Text("A varredura de vulnerabilidades continua. Entre na Cultura Builder para receber a análise e o prompt de correção.")
                        .font(.system(size: 9.8, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                Button {
                    model.copyLoginCommand()
                } label: {
                    Label("Copiar comando", systemImage: "doc.on.doc")
                }
                .buttonStyle(SurfaceButtonStyle(tint: CBTheme.high))

                Button {
                    Task { await model.refreshAuth(force: false) }
                } label: {
                    Text(model.isRefreshingAuth ? "Verificando…" : "Já fiz login")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(model.isRefreshingAuth)

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(
            CBTheme.high.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
    }
}

struct EmptyPanelCard: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle().fill(CBTheme.limeMuted)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CBTheme.lime)
            }
            .frame(width: 52, height: 52)

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(message)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(actionTitle, action: action)
                .buttonStyle(LimeButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(
            CBTheme.surface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

struct PackageRow: View {
    let package: PackageAggregate

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(package.severity.color)
                .frame(width: 5, height: 5)

            Text(package.name)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(CBTheme.text)
                .lineLimit(1)

            Text(package.installedVersion)
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundStyle(CBTheme.textTertiary)
                .lineLimit(1)

            if let fixed = package.fixedVersion {
                Image(systemName: "arrow.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(CBTheme.textTertiary)
                Text(fixed)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CBTheme.mint)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if package.hasKEV {
                KEVBadge()
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct ProjectAlertCard: View {
    let alert: ProjectAlert
    let expanded: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    let onDetails: () -> Void
    let onOpenFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(alert.risk.color)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            RiskBadge(risk: alert.risk)
                            if alert.hasKEV { KEVBadge() }
                            Spacer(minLength: 4)
                            if alert.llmUsed {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(CBTheme.lime)
                                    .help("Diagnóstico gerado pela Cultura Builder")
                            }
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(CBTheme.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.project.name)
                                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(CBTheme.text)
                                .lineLimit(1)
                            Text(alert.project.path.homeAbbreviated)
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Text(Vocabulary.headline(alert.headline))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 9) {
                            Label("Vulnerabilidades", systemImage: "shield.lefthalf.filled")
                            Label(Vocabulary.quantity(alert.packageCount, "pacote", "pacotes"), systemImage: "shippingbox")
                        }
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 11)
                    .padding(.trailing, 11)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !expanded {
                HStack(spacing: 6) {
                    ForEach(Array(alert.packageAggregates.prefix(2))) { package in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(package.severity.color)
                                .frame(width: 4, height: 4)
                            Text(package.name)
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    if alert.packageCount > 2 {
                        Text("+\(alert.packageCount - 2)")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.leading, 13)
                .padding(.bottom, 10)
            }

            if expanded {
                Divider().overlay(CBTheme.hairline).padding(.leading, 13)

                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Diagnóstico")
                        Text(Vocabulary.prose(alert.diagnosis))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "O que fazer")
                        Text(Vocabulary.prose(alert.recommendation))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            SectionLabel(text: "Pacotes afetados")
                            Spacer()
                            Text("\(alert.packageCount)")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(CBTheme.textTertiary)
                        }
                        ForEach(Array(alert.packageAggregates.prefix(5))) { package in
                            PackageRow(package: package)
                        }
                        if alert.packageCount > 5 {
                            Text("+ \(Vocabulary.quantity(alert.packageCount - 5, "pacote", "pacotes")) no detalhe completo")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(CBTheme.textTertiary)
                                .padding(.top, 2)
                        }
                    }

                    HStack(spacing: 7) {
                        Button(action: onCopy) {
                            Label("Copiar prompt", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(LimeButtonStyle())

                        Button(action: onDetails) {
                            Text("Abrir detalhes")
                        }
                        .buttonStyle(SurfaceButtonStyle())

                        Spacer(minLength: 0)

                        Button(action: onOpenFolder) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(IconButtonStyle(size: 30))
                        .help("Abrir pasta no Finder")
                    }
                }
                .padding(.leading, 13)
                .padding(.trailing, 12)
                .padding(.vertical, 13)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            CBTheme.surface,
            in: RoundedRectangle(cornerRadius: CBTheme.radius, style: .continuous)
        )
        .animation(.easeInOut(duration: 0.2), value: expanded)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
            Text(message)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(CBTheme.text)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct WarningSummary: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(CBTheme.high)
                Text("Avisos da varredura")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            ForEach(Array(warnings.prefix(3)), id: \.self) { warning in
                Text("· \(warning)")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CBTheme.high.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}
