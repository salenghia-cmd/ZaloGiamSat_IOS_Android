import Foundation

/// Cấu hình động lấy từ tab "Config" của Google Sheet (action=config). Admin sửa trên sheet,
/// app tự đổi theo: tên app, liên hệ, logo, phiên bản mới, số lần sai tối đa + phút khóa.
@MainActor
final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()

    @Published var appName = "Zalo Giám Sát"
    @Published var contact = ""
    @Published var logoURL = ""
    @Published var latestVersion = ""
    @Published var maxAttempts = 5
    @Published var lockMinutes = 5

    private let d = UserDefaults.standard
    private init() { load() }

    private func load() {
        appName = d.string(forKey: "cfg.appName") ?? appName
        contact = d.string(forKey: "cfg.contact") ?? ""
        logoURL = d.string(forKey: "cfg.logoURL") ?? ""
        latestVersion = d.string(forKey: "cfg.latestVersion") ?? ""
        let ma = d.integer(forKey: "cfg.maxAttempts"); if ma > 0 { maxAttempts = ma }
        let lm = d.integer(forKey: "cfg.lockMinutes"); if lm > 0 { lockMinutes = lm }
    }

    func refresh() async {
        guard var comps = URLComponents(string: Zalo.licenseEndpoint) else { return }
        comps.queryItems = [URLQueryItem(name: "action", value: "config")]
        guard let url = comps.url else { return }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 20
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let cfg = obj["config"] as? [String: Any] else { return }
            apply(cfg)
        } catch {}
    }

    private func apply(_ cfg: [String: Any]) {
        func str(_ k: String) -> String? {
            guard let v = cfg[k] as? String, !v.isEmpty else { return nil }
            return v
        }
        if let v = str("ten_app")        { appName = v;       d.set(v, forKey: "cfg.appName") }
        if let v = str("lien_he")        { contact = v;       d.set(v, forKey: "cfg.contact") }
        if let v = str("logo_url")       { logoURL = v;       d.set(v, forKey: "cfg.logoURL") }
        if let v = str("latest_version") { latestVersion = v; d.set(v, forKey: "cfg.latestVersion") }
        if let v = str("max_attempts"), let n = Int(v) { maxAttempts = n; d.set(n, forKey: "cfg.maxAttempts") }
        if let v = str("lock_minutes"), let n = Int(v) { lockMinutes = n; d.set(n, forKey: "cfg.lockMinutes") }
    }

    /// Có bản mới hơn bản đang chạy không (so sánh latest_version với app version).
    var hasUpdate: Bool {
        guard !latestVersion.isEmpty else { return false }
        return compare(LicenseManager.appVersion, latestVersion) < 0
    }

    private func compare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}
