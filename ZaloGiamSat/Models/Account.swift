import Foundation

/// Một tài khoản Zalo = một slot trên dashboard, kèm 1 kho dữ liệu web RIÊNG (dataStoreID).
/// `dataStoreID` được dùng cho `WKWebsiteDataStore(forIdentifier:)` (iOS 17+) để mỗi tài
/// khoản có cookie/localStorage/IndexedDB tách biệt -> đăng nhập N Zalo song song.
/// Đây là bản tương đương của `android:process=":accN"` + `setDataDirectorySuffix(...)`.
struct Account: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var slot: Int
    var name: String
    var enabled: Bool          // bật = giám sát nền (giữ phiên sống để nhận tin)
    let dataStoreID: UUID      // khóa kho dữ liệu web cô lập, cố định theo tài khoản

    init(id: UUID = UUID(), slot: Int, name: String, enabled: Bool = true, dataStoreID: UUID = UUID()) {
        self.id = id
        self.slot = slot
        self.name = name
        self.enabled = enabled
        self.dataStoreID = dataStoreID
    }

    var displayName: String { name.isEmpty ? "Zalo #\(slot + 1)" : name }
}
