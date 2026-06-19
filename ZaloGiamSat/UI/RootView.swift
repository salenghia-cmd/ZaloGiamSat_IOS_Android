import SwiftUI

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
    }
}
