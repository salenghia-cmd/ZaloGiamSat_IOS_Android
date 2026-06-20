import SwiftUI

/// Màn đăng nhập: SĐT + Mã kích hoạt. Giao diện (tên app, logo, liên hệ, báo bản mới) lấy
/// động từ tab Config của sheet qua RemoteConfig. Khóa tạm sau N lần sai (max_attempts/lock_minutes).
struct LoginView: View {
    @EnvironmentObject var license: LicenseManager
    @EnvironmentObject var config: RemoteConfig
    @State private var phone = ""
    @State private var key = ""
    @State private var loading = false
    @State private var error = ""

    private let brand = Color(red: 0, green: 0.408, blue: 1.0)

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            logo
            Text(config.appName).font(.title).bold()
            Text("Đăng nhập để sử dụng").foregroundStyle(.secondary)

            if config.hasUpdate {
                Text("Có bản mới \(config.latestVersion)" +
                     (config.contact.isEmpty ? "" : " — liên hệ \(config.contact) để cập nhật"))
                    .font(.caption).foregroundStyle(.orange)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }

            VStack(spacing: 12) {
                TextField("Số điện thoại", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                TextField("Mã kích hoạt", text: $key)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            if !error.isEmpty {
                Text(error)
                    .foregroundStyle(.red).font(.callout)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }

            Button(action: doLogin) {
                HStack(spacing: 8) {
                    if loading { ProgressView().tint(.white) }
                    Text(loading ? "Đang kiểm tra…" : "Đăng nhập").bold()
                }
                .frame(maxWidth: .infinity).padding()
                .background(brand).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(loading || phone.isEmpty || key.isEmpty)
            .padding(.horizontal)

            if !config.contact.isEmpty {
                Text("Liên hệ: \(config.contact)")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Spacer()
            Text("Chỉ dùng cho tài khoản Zalo do CHÍNH BẠN sở hữu/được ủy quyền.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding()
        }
    }

    @ViewBuilder private var logo: some View {
        Group {
            if let u = URL(string: config.logoURL), !config.logoURL.isEmpty {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    Image("LaunchLogo").resizable().scaledToFit()
                }
            } else {
                Image("LaunchLogo").resizable().scaledToFit()
            }
        }
        .frame(width: 78, height: 78)
        .padding(14)
        .background(brand)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func doLogin() {
        // Đang bị khóa do sai nhiều lần?
        let until = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "login.lockUntil"))
        if Date() < until {
            let mins = max(1, Int(until.timeIntervalSinceNow / 60) + 1)
            error = "Sai quá nhiều lần. Thử lại sau \(mins) phút."
            return
        }
        loading = true; error = ""
        Task {
            let r = await license.login(
                phone: phone.trimmingCharacters(in: .whitespaces),
                key: key.trimmingCharacters(in: .whitespaces)
            )
            loading = false
            if r.ok {
                UserDefaults.standard.set(0, forKey: "login.attempts")
                UserDefaults.standard.set(0.0, forKey: "login.lockUntil")
            } else {
                if r.reason != "NETWORK" { recordFail() }
                error = message(for: r.reason)
            }
        }
    }

    private func recordFail() {
        let d = UserDefaults.standard
        var n = d.integer(forKey: "login.attempts") + 1
        if n >= config.maxAttempts {
            d.set(Date().addingTimeInterval(Double(config.lockMinutes) * 60).timeIntervalSince1970,
                  forKey: "login.lockUntil")
            n = 0
        }
        d.set(n, forKey: "login.attempts")
    }

    private func message(for reason: String) -> String {
        let lh = config.contact.isEmpty ? "người bán" : config.contact
        switch reason {
        case "WRONG", "NOT_FOUND": return "Sai số điện thoại hoặc mã kích hoạt."
        case "EXPIRED":      return "Mã đã hết hạn. Liên hệ \(lh) để gia hạn."
        case "OTHER_DEVICE": return "Mã đang dùng trên thiết bị khác. Liên hệ \(lh) để chuyển máy."
        case "DISABLED":     return "Tài khoản đang bị khóa."
        case "EMPTY":        return "Nhập đầy đủ số điện thoại và mã kích hoạt."
        case "NETWORK":      return "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại."
        default:             return "Đăng nhập thất bại (\(reason))."
        }
    }
}
