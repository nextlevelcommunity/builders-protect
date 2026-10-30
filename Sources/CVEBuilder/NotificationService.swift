import CVECore
import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func notifyPest(_ report: PestReport) {
        deliverPest(
            identifier: "builders-protect-pest-\(report.id.uuidString)",
            title: report.criticalCount > 0
                ? L10n.t("Pest: \(report.criticalCount) achado(s) crítico(s)", "Pest: \(report.criticalCount) critical finding(s)")
                : L10n.t("Pest: \(report.findings.count) achado(s)", "Pest: \(report.findings.count) finding(s)"),
            body: report.summary
        )
    }

    static func notifyPestPaused(_ report: PestReport) {
        deliverPest(
            identifier: "builders-protect-pest-paused-\(report.id.uuidString)",
            title: L10n.t("Pest pausou para proteger a memória"),
            body: report.pauseReason ?? L10n.t("Abra o Builders Protect para retomar a análise.", "Open Builders Protect to resume the analysis.")
        )
    }

    static func notifyRedTeam(_ report: RedTeamReport) {
        deliverRedTeam(
            identifier: "builders-protect-redteam-\(report.id.uuidString)",
            title: report.criticalCount > 0
                ? L10n.t("Red Team: \(report.criticalCount) achado(s) crítico(s)", "Red Team: \(report.criticalCount) critical finding(s)")
                : L10n.t("Red Team: \(report.findings.count) achado(s)", "Red Team: \(report.findings.count) finding(s)"),
            body: report.summary
        )
    }

    static func notifyRedTeamPaused(_ report: RedTeamReport) {
        deliverRedTeam(
            identifier: "builders-protect-redteam-paused-\(report.id.uuidString)",
            title: L10n.t("Red Team pausou para proteger a memória"),
            body: report.pauseReason ?? L10n.t("Abra o Builders Protect para retomar a análise.", "Open Builders Protect to resume the analysis.")
        )
    }

    private static func deliverRedTeam(identifier: String, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = String(Vocabulary.prose(body).prefix(240))
            content.sound = .default
            content.userInfo = ["openRedTeam": true]

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    static func notifyNetwork(_ report: NetworkReport) {
        let title: String
        if report.criticalCount > 0 {
            title = L10n.t("Minha rede: \(Vocabulary.quantity(report.criticalCount, "ponto crítico", "pontos críticos"))", "My network: \(Vocabulary.quantity(report.criticalCount, "critical point", "critical points"))")
        } else if report.highCount > 0 {
            title = L10n.t("Minha rede: \(Vocabulary.quantity(report.highCount, "ponto alto", "pontos altos"))", "My network: \(Vocabulary.quantity(report.highCount, "high point", "high points"))")
        } else {
            title = L10n.t("Minha rede: \(Vocabulary.quantity(report.findings.count, "ponto de atenção", "pontos de atenção"))", "My network: \(Vocabulary.quantity(report.findings.count, "point of attention", "points of attention"))")
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = String(Vocabulary.prose(report.summary).prefix(240))
            content.sound = .default
            content.userInfo = ["openNetwork": true]

            let request = UNNotificationRequest(
                identifier: "builders-protect-network-\(report.id.uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    private static func deliverPest(identifier: String, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = String(Vocabulary.prose(body).prefix(240))
            content.sound = .default
            content.userInfo = ["openPest": true]

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    static func notify(report: ScanReport, newFindings: Int) {
        guard report.hasFindings, newFindings > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = newFindings == 1
                ? L10n.t("1 nova vulnerabilidade encontrada", "1 new vulnerability found")
                : L10n.t("\(newFindings) novas vulnerabilidades encontradas", "\(newFindings) new vulnerabilities found")
            content.body = Vocabulary.prose(report.summary)
            content.sound = .default
            content.userInfo = ["openPanel": true]

            let request = UNNotificationRequest(
                identifier: "builders-protect-scan-\(report.id.uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
