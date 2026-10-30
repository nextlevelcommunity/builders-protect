import CVECore
import SwiftUI

enum CBTheme {
    static let background = Color(red: 0.031, green: 0.035, blue: 0.030)
    static let backgroundLifted = Color(red: 0.055, green: 0.062, blue: 0.052)
    static let surface = Color.white.opacity(0.045)
    static let surfaceStrong = Color.white.opacity(0.075)
    static let surfaceSolid = Color(red: 0.061, green: 0.067, blue: 0.058)
    static let lime = Color(red: 0.78, green: 0.96, blue: 0.38)
    static let limeDeep = Color(red: 0.55, green: 0.84, blue: 0.24)
    static let limeMuted = Color(red: 0.78, green: 0.96, blue: 0.38).opacity(0.12)
    static let text = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.34)
    static let hairline = Color.white.opacity(0.08)
    static let critical = Color(red: 1.00, green: 0.38, blue: 0.38)
    static let high = Color(red: 1.00, green: 0.64, blue: 0.26)
    static let medium = Color(red: 0.98, green: 0.83, blue: 0.40)
    static let low = Color(red: 0.53, green: 0.77, blue: 1.00)
    static let unknown = Color.white.opacity(0.44)
    static let mint = Color(red: 0.39, green: 0.88, blue: 0.64)
    static let radius: CGFloat = 16
}

extension RiskLevel {
    var color: Color {
        switch self {
        case .critical: return CBTheme.critical
        case .high: return CBTheme.high
        case .medium: return CBTheme.medium
        case .low: return CBTheme.low
        case .unknown: return CBTheme.unknown
        }
    }

    var symbol: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .low: return "info.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var actionLabel: String {
        switch self {
        case .critical: return L10n.t("Corrigir agora", "Fix now")
        case .high: return L10n.t("Priorizar", "Prioritize")
        case .medium: return L10n.t("Planejar correção", "Plan the fix")
        case .low: return L10n.t("Acompanhar", "Monitor")
        case .unknown: return L10n.t("Revisar", "Review")
        }
    }
}

extension Date {
    var relativeShort: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return L10n.t("agora", "just now") }
        if seconds < 3_600 {
            let minutes = Int(seconds / 60)
            return L10n.t("há \(minutes) min", "\(minutes) min ago")
        }
        if seconds < 86_400 {
            let hours = Int(seconds / 3_600)
            return L10n.t("há \(hours) h", "\(hours) h ago")
        }
        if seconds < 604_800 {
            let days = Int(seconds / 86_400)
            return L10n.t("há \(days) d", "\(days) d ago")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isPortuguese ? "pt_BR" : "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var fullDateTime: String {
        formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
        )
    }
}

extension String {
    var homeAbbreviated: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if hasPrefix(home) {
            return "~" + dropFirst(home.count)
        }
        return self
    }
}

struct LimeButtonStyle: ButtonStyle {
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(CBTheme.background)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                LinearGradient(
                    colors: [CBTheme.lime, CBTheme.limeDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SurfaceButtonStyle: ButtonStyle {
    var fullWidth = false
    var tint: Color = CBTheme.text
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                CBTheme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = CBTheme.textSecondary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                configuration.isPressed ? CBTheme.surfaceStrong : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var tint: Color = CBTheme.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                configuration.isPressed ? CBTheme.surfaceStrong : CBTheme.surface,
                in: Circle()
            )
    }
}
