import UserNotifications
import Foundation

enum Notifier {
    static func requestAuthorization() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            RLog(.notice, category: "general", "通知許可リクエスト失敗: \(error.localizedDescription)")
        }
    }

    static func notifyFailure(share: ShareConfig, consecutiveCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Remora: 接続失敗"
        content.body = "\(share.host)/\(share.shareName) への接続が \(consecutiveCount) 回連続で失敗しました"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "mount-failure-\(share.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                RLog(.error, category: "general", "通知送信失敗: \(error.localizedDescription)")
            }
        }
    }
}
