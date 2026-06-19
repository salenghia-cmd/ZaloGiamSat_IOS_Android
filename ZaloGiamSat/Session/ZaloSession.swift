import Foundation
import WebKit
import UIKit

/// Một phiên Zalo Web sống độc lập (tương đương AccountService.kt giữ WebView sống nền).
/// WebView được GIỮ bởi SessionManager nên vẫn chạy khi rời màn hình; Activity/SwiftUI chỉ
/// "mượn" ra hiển thị rồi trả lại.
@MainActor
final class ZaloSession: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    let account: Account
    let webView: WKWebView
    @Published private(set) var unread: Int = 0

    /// Gọi mỗi khi số chưa đọc đổi (SessionManager dùng để gộp tổng + badge).
    var onUnreadChange: ((Int) -> Void)?

    private var titleObs: NSKeyValueObservation?

    init(account: Account) {
        self.account = account

        let config = WKWebViewConfiguration()
        // KHO DỮ LIỆU WEB CÔ LẬP theo tài khoản: cookie/localStorage/IndexedDB riêng biệt.
        // Đây là tương đương iOS của setDataDirectorySuffix("zalo_accN") bên Android.
        // iOS 16: mỗi tài khoản một kho EPHEMERAL riêng -> cô lập để đăng nhập nhiều Zalo song song.
        // (iOS 16 không có WKWebsiteDataStore(forIdentifier:) như iOS 17 nên ta tự lưu cookie để giữ đăng nhập.)
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: Zalo.visibilityJS,
                                       injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ucc.addUserScript(WKUserScript(source: Zalo.notifyHookJS,
                                       injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ucc.addUserScript(WKUserScript(source: Zalo.unreadReporterJS,
                                       injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = ucc

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        // Proxy YẾU để tránh giữ vòng: ucc -> handler -> self -> webView -> config -> ucc.
        ucc.add(WeakScriptMessageHandler(self), name: Zalo.bridgeName)

        webView.customUserAgent = Zalo.desktopUA
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }

        // Số chưa đọc đọc từ tiêu đề tab Zalo Web "(3) Zalo" (giống onReceivedTitle bên Android).
        titleObs = webView.observe(\.title, options: [.new, .initial]) { [weak self] wv, _ in
            let title = wv.title
            Task { @MainActor in self?.updateUnread(from: title) }
        }

        restoreCookiesThenLoad()
    }

    func load() { webView.load(URLRequest(url: Zalo.chatURL)) }
    func reload() { webView.reload() }

    /// Khôi phục cookie đã lưu của tài khoản (giữ đăng nhập) rồi mới nạp trang.
    private func restoreCookiesThenLoad() {
        let saved = CookieStore.load(for: account.dataStoreID)
        guard !saved.isEmpty else { load(); return }
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        for c in saved { group.enter(); store.setCookie(c) { group.leave() } }
        group.notify(queue: .main) { [weak self] in Task { @MainActor in self?.load() } }
    }

    /// Lưu cookie hiện tại của phiên (để lần mở sau đỡ phải quét QR lại).
    func saveCookies() {
        let id = account.dataStoreID
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            CookieStore.save(cookies, for: id)
        }
    }

    /// Đăng xuất: xóa toàn bộ dữ liệu web của tài khoản này rồi nạp lại trang QR.
    func clearSession() {
        CookieStore.delete(for: account.dataStoreID)
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) { [weak self] in
                Task { @MainActor in self?.load() }
            }
        }
    }

    private func updateUnread(from title: String?) {
        setUnread(Zalo.parseUnread(from: title))
    }

    private func setUnread(_ n: Int) {
        guard n != unread else { return }
        unread = n
        onUnreadChange?(n)
    }

    // MARK: Lưu ảnh QR để tự đăng nhập trên cùng máy (không cần điện thoại thứ 2)

    /// Làm tươi mã QR (nếu có nút "Lấy mã mới") -> chụp ảnh trang -> lưu vào thư viện Ảnh.
    func saveQRToPhotos() async -> (ok: Bool, message: String) {
        let refreshed = await evalRefreshQR()
        try? await Task.sleep(nanoseconds: refreshed ? 2_600_000_000 : 500_000_000)
        guard let image = await snapshot() else {
            return (false, "Chưa chụp được màn hình — đợi trang tải xong rồi thử lại.")
        }
        let saved = await PhotoSaver.save(image)
        return saved
            ? (true, "Đã lưu ảnh QR vào thư viện Ảnh.\nMở Zalo → Quét QR → chọn ảnh vừa lưu để đăng nhập.")
            : (false, "Không lưu được ảnh (thiếu quyền truy cập Ảnh?). Vào Cài đặt → Ảnh để cấp quyền.")
    }

    private func evalRefreshQR() async -> Bool {
        await withCheckedContinuation { cont in
            webView.evaluateJavaScript(Zalo.refreshQRJS) { result, _ in
                cont.resume(returning: (result as? String) == "REFRESHED")
            }
        }
    }

    private func snapshot() async -> UIImage? {
        await withCheckedContinuation { cont in
            let cfg = WKSnapshotConfiguration()
            webView.takeSnapshot(with: cfg) { image, _ in
                cont.resume(returning: image)
            }
        }
    }

    // MARK: JS -> Swift (có tin mới)

    nonisolated func userContentController(_ ucc: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        guard message.name == Zalo.bridgeName,
              let dict = message.body as? [String: Any] else { return }

        // Báo số chưa đọc (từ unreadReporterJS).
        if (dict["kind"] as? String) == "unread" {
            let count = (dict["count"] as? Int) ?? Int((dict["count"] as? Double) ?? 0)
            Task { @MainActor in self.setUnread(count) }
            return
        }

        // Còn lại: thông báo tin mới (từ notifyHookJS).
        let title = (dict["title"] as? String) ?? ""
        let body = (dict["body"] as? String) ?? ""
        let acc = account
        Task { @MainActor in
            NotificationManager.shared.showNewMessage(account: acc, title: title, body: body)
        }
    }

    // Lưu cookie sau khi trang tải xong (bắt phiên đăng nhập ngay sau khi quét QR thành công).
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.saveCookies()
        }
    }

    func teardown() {
        titleObs?.invalidate(); titleObs = nil
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
    }
}

/// Bọc YẾU một WKScriptMessageHandler để tránh rò bộ nhớ kinh điển của WKUserContentController.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) { self.delegate = delegate; super.init() }
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(ucc, didReceive: message)
    }
}
