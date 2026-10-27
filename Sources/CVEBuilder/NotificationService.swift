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
                ? "Pest: \(report.criticalCount) achado(s) crítico(s)"
                : "Pest: \(report.findings.count) achado(s)",
            body: report.summary
        )
    }

    static func notifyPestPaused(_ report: PestReport) {
        deliverPest(
            identifier: "builders-protect-pest-paused-\(report.id.uuidString)",
            title: "Pest pausou para proteger a memória",
            body: report.pauseReason ?? "Abra o Builders Protect para retomar a análise."
        )
    }

    static func notifyNetwork(_ report: NetworkReport) {
        let title: String
        if report.criticalCount > 0 {
            title = "Minha rede: \(Vocabulary.quantity(report.criticalCount, "ponto crítico", "pontos críticos"))"
        } else if report.highCount > 0 {
            title = "Minha rede: \(Vocabulary.quantity(report.highCount, "ponto alto", "pontos altos"))"
        } else {
            title = "Minha rede: \(Vocabulary.quantity(report.findings.count, "ponto de atenção", "pontos de atenção"))"
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
                ? "1 nova vulnerabilidade encontrada"
                : "\(newFindings) novas vulnerabilidades encontradas"
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
