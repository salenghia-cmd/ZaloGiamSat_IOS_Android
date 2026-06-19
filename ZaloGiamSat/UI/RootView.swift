import SwiftUI
import Combine

/// Cổng vào app: chưa đăng nhập -> LoginView; đã có license -> DashboardView.
struct RootView: View {
    @EnvironmentObject var license: LicenseManager
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var sessions: SessionManager

    var body: some View {
        Group {
            if license.isLicensed {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .task {
            NotificationManager.shared.configure()
            await license.revalidate()
            if license.isLicensed {
                sessions.startEnabled(store.accounts)
                license.ping()
            }
        }
        .onChange(of: license.isLicensed) { licensed in
            if licensed {
                sessions.startEnabled(store.accounts)
                license.ping()
            }
        }
        // Kiểm tra license định kỳ mỗi 2 phút -> hết hạn / đổi mã / bị khóa thì tự đăng xuất ngay cả khi app đang mở.
        .onReceive(Timer.publish(every: 120, on: .main, in: .common).autoconnect()) { _ in
            if license.isLicensed { Task { await license.revalidate() } }
        }
    }
}
