import SwiftUI

/// Màn "Hướng dẫn / Giới thiệu" — mở lại được bất cứ lúc nào từ nút ⓘ trên dashboard.
/// Luôn cho xem lại cảnh báo pháp lý + cách đăng nhập + lưu ý chạy nền + phiên bản.
struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    legalCard

                    section("Cách đăng nhập", icon: "qrcode") {
                        step(1, "Bấm dấu + ở dashboard để thêm một Zalo (đặt tên gợi nhớ, vd \"CSKH 1\").")
                        step(2, "Chạm vào slot để mở — trang Zalo Web hiện mã QR.")
                        step(3, "Quét QR bằng app Zalo trên điện thoại có tài khoản đó. Hoặc dùng menu ⋯ → \"Lưu ảnh QR để đăng nhập\" rồi mở Zalo quét ảnh ngay trên máy này.")
                    }

                    section("Giám sát nhiều Zalo", icon: "bell.badge") {
                        bullet("Mỗi slot là một phiên Zalo độc lập, cookie riêng — đăng nhập nhiều tài khoản song song.")
                        bullet("Badge đỏ = số tin chưa đọc; có thông báo khi tới tin mới.")
                        bullet("Nhấn giữ (hoặc vuốt) một slot để: Mở · Đổi tên · Bật/Tắt giám sát nền · Xóa.")
                    }

                    section("Lưu ý chạy nền (iOS)", icon: "exclamationmark.triangle") {
                        bullet("iOS không cho phiên web chạy nền lâu như Android. App nhận tin tức thời khi đang mở / vừa chuyển nền; khi bị treo lâu, iOS chỉ làm tươi số chưa đọc thưa thớt theo lịch của hệ điều hành.")
                        bullet("Bật nhiều phiên tốn RAM/pin — thực tế 4–6 tài khoản là hợp lý; nên cắm sạc khi giám sát liên tục.")
                    }
                }
                .padding()
            }
            .navigationTitle("Hướng dẫn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    // MARK: Thành phần

    private var header: some View {
        HStack(spacing: 14) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(width: 60, height: 60)
                .background(Color(red: 0, green: 0.408, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("Zalo Giám Sát").font(.title2).bold()
                Text("Phiên bản \(appVersion)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Lưu ý pháp lý", systemImage: "checkmark.shield").font(.headline)
            Text("Chỉ dùng cho tài khoản Zalo do CHÍNH BẠN sở hữu hoặc được ủy quyền (vd: nhiều Zalo CSKH của shop). Theo dõi Zalo của người khác khi họ không biết là vi phạm pháp luật (VN: Điều 159 BLHS; Nghị định 15/2020).")
                .font(.callout)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private func section<Content: View>(
        _ title: String, icon: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.caption).bold().foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))
            Text(text).font(.callout)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(text).font(.callout)
        }
    }
}
