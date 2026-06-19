import Foundation
import UIKit

/// Quản lý đăng nhập/license: gọi Google Apps Script (chung server bản Android), lưu phiên,
/// kiểm tra lại khi mở app, heartbeat. Khóa "1 mã = 1 máy" do server xử lý qua `device`.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var isLicensed = false
    @Published private(set) var maxAccounts = 5
    @Published private(set) var expiry = ""

    private let d = UserDefaults.standard
    private enum Keys {
        static let phone = "lic.phone", key = "lic.key", expiry = "lic.expiry"
        static let max = "lic.max", device = "lic.device"
    }

    private init() {
        isLicensed = !savedPhone.isEmpty && !savedKey.isEmpty
        let m = d.integer(forKey: Keys.max)
        maxAccounts = m > 0 ? m : 5
        expiry = d.string(forKey: Keys.expiry) ?? ""
    }

    var savedPhone: String { d.string(forKey: Keys.phone) ?? "" }
    var savedKey: String { d.string(forKey: Keys.key) ?? "" }

    /// Mã định danh thiết bị cố định (server dùng để khóa 1 mã = 1 máy).
    var deviceId: String {
        if let id = d.string(forKey: Keys.device) { return id }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        d.set(id, forKey: Keys.device)
        return id
    }

    struct Outcome { let ok: Bool; let reason: String; let expiry: String; let max: Int }

    /// Đăng nhập: kiểm tra rồi lưu nếu hợp lệ.
    func login(phone: String, key: String) async -> Outcome {
        let r = await call(action: nil, phone: phone, key: key)
        if r.ok {
            d.set(phone, forKey: Keys.phone)
            d.set(key, forKey: Keys.key)
            d.set(r.expiry, forKey: Keys.expiry)
            d.set(r.max, forKey: Keys.max)
            isLicensed = true; expiry = r.expiry; maxAccounts = r.max
        }
        return r
    }

    /// Kiểm tra lại license đã lưu (mở app / quay lại app). Sai (không phải lỗi mạng) -> tự đăng xuất.
    func revalidate() async {
        guard isLicensed, !savedPhone.isEmpty, !savedKey.isEmpty else { return }
        let r = await call(action: nil, phone: savedPhone, key: savedKey)
        if r.ok {
            d.set(r.expiry, forKey: Keys.expiry); d.set(r.max, forKey: Keys.max)
            expiry = r.expiry; maxAccounts = r.max
        } else if r.reason != "NETWORK" {
            logout()
        }
    }

    /// Báo "còn hoạt động" về sheet (cập nhật LAST_SEEN/STATUS). Không cần đợi kết quả.
    func ping() {
        guard !savedPhone.isEmpty else { return }
        Task { _ = await call(action: "ping", phone: savedPhone, key: savedKey) }
    }

    func logout() {
        [Keys.phone, Keys.key, Keys.expiry, Keys.max].forEach { d.removeObject(forKey: $0) }
        isLicensed = false
        // Giữ Keys.device để lần đăng nhập sau vẫn khớp máy đã bind (không bị OTHER_DEVICE).
    }

    // MARK: Gọi server

    private func call(action: String?, phone: String, key: String) async -> Outcome {
        guard var comps = URLComponents(string: Zalo.licenseEndpoint) else {
            return Outcome(ok: false, reason: "BADURL", expiry: "", max: 5)
        }
        var items = [
            URLQueryItem(name: "phone", value: phone),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "device", value: deviceId),
        ]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        if action == "ping" { items.append(URLQueryItem(name: "event", value: "online")) }
        comps.queryItems = items

        guard let url = comps.url else { return Outcome(ok: false, reason: "BADURL", expiry: "", max: 5) }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 20
            let (data, _) = try await URLSession.shared.data(for: req)   // URLSession tự theo redirect của Apps Script
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let ok = (obj["ok"] as? Bool) ?? false
            let reason = (obj["reason"] as? String) ?? (ok ? "OK" : "UNKNOWN")
            let exp = (obj["expiry"] as? String) ?? ""
            let mx = (obj["max"] as? Int) ?? Int((obj["max"] as? Double) ?? 0)
            return Outcome(ok: ok, reason: reason, expiry: exp, max: mx > 0 ? mx : 5)
        } catch {
            return Outcome(ok: false, reason: "NETWORK", expiry: "", max: 5)
        }
    }
}
