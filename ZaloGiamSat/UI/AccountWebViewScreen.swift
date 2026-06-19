import SwiftUI
import WebKit

/// Vỏ hiển thị một phiên Zalo: "mượn" WebView đang sống trong SessionManager ra hiển thị,
/// trả lại khi rời màn hình. Tương đương BaseAccountActivity.kt bên Android.
struct AccountWebViewScreen: View {
    let account: Account
    @EnvironmentObject var sessions: SessionManager

    @State private var savingQR = false
    @State private var showQRResult = false
    @State private var qrMessage = ""

    var body: some View {
        AccountWebView(account: account)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(account.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            sessions.session(for: account).reload()
                        } label: {
                            Label("Tải lại", systemImage: "arrow.clockwise")
                        }
                        Button {
                            saveQR()
                        } label: {
                            Label("Lưu ảnh QR để đăng nhập", systemImage: "qrcode")
                        }
                        Button(role: .destructive) {
                            sessions.clearSession(account)
                        } label: {
                            Label("Đăng xuất (xóa phiên)", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if savingQR {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView("Đang lưu ảnh QR…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .alert("Lưu ảnh QR", isPresented: $showQRResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(qrMessage)
            }
            .onAppear { _ = sessions.session(for: account) }
    }

    private func saveQR() {
        savingQR = true
        Task {
            let result = await sessions.session(for: account).saveQRToPhotos()
            qrMessage = result.message
            savingQR = false
            showQRResult = true
        }
    }
}

/// Cầu nối UIKit: gắn WKWebView (do SessionManager giữ) vào cây view, gỡ ra khi đóng nhưng
/// KHÔNG hủy — phiên tiếp tục sống nền.
struct AccountWebView: UIViewRepresentable {
    let account: Account

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let wv = SessionManager.shared.session(for: account).webView
        wv.removeFromSuperview() // gỡ khỏi parent cũ nếu đang được "mượn" nơi khác
        wv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Trả WebView về SessionManager: chỉ gỡ khỏi màn hình, không destroy.
        uiView.subviews.forEach { $0.removeFromSuperview() }
    }
}
