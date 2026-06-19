import SwiftUI

/// Màn đăng nhập: SĐT + Mã kích hoạt, kiểm tra qua LicenseManager (server Google Apps Script).
struct LoginView: View {
    @EnvironmentObject var license: LicenseManager
    @State private var phone = ""
    @State private var key = ""
    @State private var loading = false
    @State private var error = ""

    private let brand = Color(red: 0, green: 0.408, blue: 1.0)

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image("LaunchLogo")
                .resizable().scaledToFit()
                .frame(width: 78, height: 78)
                .padding(14)
                .background(brand)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text("Zalo Giám Sát").font(.title).bold()
            Text("Đăng nhập để sử dụng").foregroundStyle(.secondary)

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

            Spacer()
            Text("Chỉ dùng cho tài khoản Zalo do CHÍNH BẠN sở hữu/được ủy quyền.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding()
        }
    }

    private func doLogin() {
        loading = true; error = ""
        Task {
            let r = await license.login(
                phone: phone.trimmingCharacters(in: .whitespaces),
                key: key.trimmingCharacters(in: .whitespaces)
            )
            loading = false
            if !r.ok { error = message(for: r.reason) }
        }
    }

    private func message(for reason: String) -> String {
        switch reason {
        case "WRONG", "NOT_FOUND": return "Sai số điện thoại hoặc mã kích hoạt."
        case "EXPIRED":      return "Mã đã hết hạn. Liên hệ người bán để gia hạn."
        case "OTHER_DEVICE": return "Mã đang dùng trên thiết bị khác. Liên hệ admin để chuyển máy (xóa ô thiết bị trong sheet)."
        case "DISABLED":     return "Tài khoản đang bị khóa."
        case "EMPTY":        return "Nhập đầy đủ số điện thoại và mã kích hoạt."
        case "NETWORK":      return "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại."
        default:             return "Đăng nhập thất bại (\(reason))."
        }
    }
}
