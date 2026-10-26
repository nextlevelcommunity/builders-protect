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
