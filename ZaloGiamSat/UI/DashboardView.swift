import SwiftUI

/// Dashboard: danh sách slot Zalo + badge chưa đọc + thêm/đổi tên/bật-tắt/xóa.
/// Tương đương MainActivity.kt bên Android.
struct DashboardView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var sessions: SessionManager
    @EnvironmentObject var notif: NotificationManager
    @EnvironmentObject var license: LicenseManager
    @EnvironmentObject var config: RemoteConfig

    /// Số Zalo tối đa: nhỏ hơn giữa giới hạn app (10) và giới hạn license (cột I trong sheet).
    private var effectiveMax: Int { min(Zalo.maxSlots, license.maxAccounts) }

    @State private var path: [Account] = []
    @State private var showAdd = false
    @State private var newName = ""
    @State private var renaming: Account?
    @State private var renameText = ""
    @State private var showDisclaimer = false
    @State private var showGuide = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    if store.accounts.isEmpty {
                        Text("Bấm + để thêm Zalo, mở slot rồi quét QR bằng app Zalo trên điện thoại có tài khoản đó.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    ForEach(store.accounts) { acc in
                        NavigationLink(value: acc) {
                            AccountRow(account: acc,
                                       unread: sessions.unread(for: acc),
                                       live: acc.enabled)
                        }
                        .contextMenu { menu(for: acc) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.remove(acc.id) } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                            Button { startRename(acc) } label: {
                                Label("Đổi tên", systemImage: "pencil")
                            }.tint(.blue)
                        }
                    }
                } header: {
                    Text("Tài khoản — \(store.accounts.count)/\(effectiveMax)")
                } footer: {
                    Text("⚠️ Chỉ dùng cho tài khoản Zalo do CHÍNH BẠN sở hữu/được ủy quyền. Theo dõi Zalo của người khác khi họ không biết là vi phạm pháp luật.")
                        .font(.caption2)
                }
            }
            .navigationTitle(config.appName)
            .navigationDestination(for: Account.self) { acc in
                AccountWebViewScreen(account: acc)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showGuide = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if sessions.totalUnread > 0 {
                        Text("● \(sessions.totalUnread)")
                            .foregroundStyle(.red).font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { newName = ""; showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.accounts.count >= effectiveMax)
                }
            }
            .alert("Thêm Zalo", isPresented: $showAdd) {
                TextField("Tên gợi nhớ (vd: CSKH 1)", text: $newName)
                Button("Thêm") {
                    if let acc = store.add(name: newName.trimmingCharacters(in: .whitespaces)),
                       acc.enabled {
                        sessions.start(acc)
                    }
                }
                Button("Hủy", role: .cancel) {}
            }
            .alert("Đổi tên", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Tên mới", text: $renameText)
                Button("Lưu") {
                    if let r = renaming { store.rename(r.id, to: renameText) }
                    renaming = nil
                }
                Button("Hủy", role: .cancel) { renaming = nil }
            }
            .sheet(isPresented: $showGuide) {
                GuideView().environmentObject(license).environmentObject(config)
            }
        }
        .onChange(of: notif.openSlot) { slot in
            if let slot, let acc = store.account(slot: slot) {
                path = [acc]
                notif.openSlot = nil
            }
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "seenDisclaimer") { showDisclaimer = true }
        }
        .alert("Lưu ý pháp lý", isPresented: $showDisclaimer) {
            Button("Tôi hiểu") { UserDefaults.standard.set(true, forKey: "seenDisclaimer") }
        } message: {
            Text("App chỉ để quản lý/giám sát các tài khoản Zalo do CHÍNH BẠN sở hữu hoặc được ủy quyền (vd: nhiều Zalo CSKH của shop).\n\nTheo dõi Zalo của người khác khi họ không biết là vi phạm pháp luật (VN: Điều 159 BLHS; Nghị định 15/2020).")
        }
    }

    @ViewBuilder
    private func menu(for acc: Account) -> some View {
        Button { path = [acc] } label: {
            Label("Mở", systemImage: "bubble.left.and.bubble.right")
        }
        Button { startRename(acc) } label: {
            Label("Đổi tên", systemImage: "pencil")
        }
        Button { store.setEnabled(acc.id, !acc.enabled) } label: {
            Label(acc.enabled ? "Tắt giám sát nền" : "Bật giám sát nền",
                  systemImage: acc.enabled ? "pause.circle" : "play.circle")
        }
        Button(role: .destructive) { store.remove(acc.id) } label: {
            Label("Xóa", systemImage: "trash")
        }
    }

    private func startRename(_ acc: Account) {
        renaming = acc
        renameText = acc.name
    }
}

/// Một dòng tài khoản trên dashboard.
struct AccountRow: View {
    let account: Account
    let unread: Int
    let live: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                Text(live ? "● Đang giám sát nền" : "Tạm tắt")
                    .font(.caption2)
                    .foregroundStyle(live ? .green : .secondary)
            }
            Spacer()
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.red))
            }
        }
    }
}
