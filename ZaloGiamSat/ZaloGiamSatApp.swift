import SwiftUI
import BackgroundTasks
import UIKit

@main
struct ZaloGiamSatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AccountStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(SessionManager.shared)
                .environmentObject(NotificationManager.shared)
                .environmentObject(LicenseManager.shared)
        }
    }
}

/// Đăng ký + xử lý tác vụ chạy nền theo lịch của iOS (BGAppRefreshTask).
///
/// LƯU Ý THẬT LÒNG: iOS KHÔNG cho WebView chạy nền lâu dài như foreground service của Android.
/// Khi app bị treo (suspended), JS/websocket của Zalo Web dừng. Tác vụ dưới đây chỉ giúp iOS
/// thỉnh thoảng "đánh thức" app để làm tươi số chưa đọc — tần suất do hệ điều hành quyết định
/// (có thể vài chục phút/lần hoặc thưa hơn). Giám sát "tức thời" chỉ chạy khi app đang mở /
/// vừa mới chuyển nền.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Zalo.refreshTaskID, using: nil) { task in
            // swiftlint:disable:next force_cast
            self.handleRefresh(task as! BGAppRefreshTask)
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task { @MainActor in SessionManager.shared.saveAll() }
        scheduleRefresh()
    }

    // Quay lại app -> kiểm tra lại license (hết hạn/bị khóa thì tự đăng xuất).
    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in await LicenseManager.shared.revalidate() }
    }

    private func scheduleRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: Zalo.refreshTaskID)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // sớm nhất 15 phút nữa
        try? BGTaskScheduler.shared.submit(req)
    }

    private func handleRefresh(_ task: BGAppRefreshTask) {
        scheduleRefresh() // luôn đặt lịch lần kế trước khi làm việc
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        Task { @MainActor in
            SessionManager.shared.reloadAll()
            // Cho WebView vài giây cập nhật tiêu đề -> số chưa đọc, rồi báo xong.
            try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
            task.setTaskCompleted(success: true)
        }
    }
}
