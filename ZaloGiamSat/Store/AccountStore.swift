import Foundation
import WebKit

/// Lưu danh sách tài khoản (UserDefaults + JSON). Tương đương AccountStore.kt bên Android.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []

    private let key = "accounts.v1"
    private let defaults = UserDefaults.standard

    init() { load() }

    // MARK: Đọc/ghi

    private func load() {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([Account].self, from: data)
        else { accounts = []; return }
        accounts = list.sorted { $0.slot < $1.slot }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: Thao tác

    private func nextFreeSlot() -> Int {
        let used = Set(accounts.map(\.slot))
        for i in 0..<Zalo.maxSlots where !used.contains(i) { return i }
        return accounts.count
    }

    @discardableResult
    func add(name: String) -> Account? {
        guard accounts.count < Zalo.maxSlots else { return nil }
        let acc = Account(slot: nextFreeSlot(), name: name)
        accounts.append(acc)
        accounts.sort { $0.slot < $1.slot }
        persist()
        return acc
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[i].name = name
        persist()
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[i].enabled = enabled
        persist()
        if enabled {
            SessionManager.shared.start(accounts[i])
        } else {
            SessionManager.shared.stop(accounts[i])
        }
    }

    func remove(_ id: UUID) {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        let acc = accounts.remove(at: i)
        persist()
        SessionManager.shared.stop(acc)
        // Xóa luôn kho dữ liệu web cô lập của tài khoản (đăng xuất sạch).
        WKWebsiteDataStore.remove(forIdentifier: acc.dataStoreID) { _ in }
    }

    func account(slot: Int) -> Account? { accounts.first { $0.slot == slot } }
}
