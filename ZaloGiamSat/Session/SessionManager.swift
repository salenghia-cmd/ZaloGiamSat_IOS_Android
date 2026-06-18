import Foundation
import WebKit

/// Giữ các phiên Zalo sống (mỗi tài khoản 1 ZaloSession) và gộp số chưa đọc.
/// Tương đương vai trò của các AccountService + MonitorService bên Android, gói trong 1 tiến trình.
@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published private(set) var unread: [UUID: Int] = [:]
    @Published private(set) var totalUnread: Int = 0

    private var sessions: [UUID: ZaloSession] = [:]

    private init() {}

    /// Tạo (nếu chưa có) và trả về phiên sống của tài khoản. Phiên được giữ lại trong manager
    /// nên tiếp tục chạy nền sau khi rời màn hình.
    @discardableResult
    func session(for account: Account) -> ZaloSession {
        if let s = sessions[account.id] { return s }
        let s = ZaloSession(account: account)
        s.onUnreadChange = { [weak self] n in
            guard let self else { return }
            self.unread[account.id] = n
            self.recomputeTotal()
        }
        sessions[account.id] = s
        unread[account.id] = 0
        return s
    }

    func start(_ account: Account) { _ = session(for: account) }

    func startEnabled(_ accounts: [Account]) {
        for a in accounts where a.enabled { start(a) }
    }

    func stop(_ account: Account) {
        sessions[account.id]?.teardown()
        sessions[account.id] = nil
        unread[account.id] = nil
        recomputeTotal()
    }

    func reloadAll() { sessions.values.forEach { $0.reload() } }

    func clearSession(_ account: Account) { sessions[account.id]?.clearSession() }

    func unread(for account: Account) -> Int { unread[account.id] ?? 0 }

    private func recomputeTotal() {
        totalUnread = unread.values.reduce(0, +)
        NotificationManager.shared.setBadge(totalUnread)
    }
}
