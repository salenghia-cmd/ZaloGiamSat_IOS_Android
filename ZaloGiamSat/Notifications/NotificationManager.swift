import Foundation
import UserNotifications

/// Thông báo tin mới + badge tổng số chưa đọc. Tương đương phần notification của MonitorService.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Slot mà người dùng yêu cầu mở khi chạm vào thông báo (DashboardView quan sát để điều hướng).
    @Published var openSlot: Int?

    private override init() { super.init() }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func showNewMessage(account: Account, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title.isEmpty ? account.displayName : title
        content.body = body
        content.subtitle = account.displayName
        content.sound = .default
        content.userInfo = ["slot": account.slot]
        let req = UNNotificationRequest(
            identifier: "msg-\(account.slot)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // Hiện thông báo cả khi app đang mở.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    // Chạm thông báo -> mở đúng slot tài khoản.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let slot = response.notification.request.content.userInfo["slot"] as? Int
        await MainActor.run { self.openSlot = slot }
    }
}
