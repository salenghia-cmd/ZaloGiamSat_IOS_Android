# Zalo Giám Sát — iOS

Bản iOS (Swift + SwiftUI + WKWebView) **ghép cặp** với app Android Kotlin sẵn có
(`../ZALOGiamSat`). Chạy **nhiều phiên Zalo Web song song** trong một app, mỗi tài khoản một
kho cookie/localStorage **tách biệt**, kèm dashboard đếm tin chưa đọc và thông báo tin mới.

> ⚠️ **Chỉ dùng cho tài khoản Zalo do CHÍNH BẠN sở hữu/được ủy quyền** (ví dụ quản lý nhiều
> Zalo CSKH của shop). Theo dõi Zalo của người khác khi họ không biết là vi phạm pháp luật VN
> (Điều 159 BLHS, Nghị định 15/2020). App buộc đăng nhập từng tài khoản bằng **quét QR** nên
> bạn phải có sẵn tài khoản đó trên một điện thoại.

Phần **gửi tin hàng loạt tự động + cào danh bạ** của bản Android **không được port** sang đây
(đó là tự động hóa spam + né phát hiện). Bản iOS này chỉ làm đúng phần **giám sát nhiều Zalo**.

---

## Ý tưởng kỹ thuật cốt lõi (đối chiếu với bản Android)

| Vấn đề | Android (bản Kotlin) | iOS (bản này) |
|---|---|---|
| Cô lập phiên để login N tài khoản | mỗi tài khoản 1 **tiến trình** `:accN` + `WebView.setDataDirectorySuffix("zalo_accN")` | mỗi tài khoản 1 **`WKWebsiteDataStore(forIdentifier:)`** riêng (iOS 17+) |
| Giữ phiên sống khi rời màn hình | WebView sống trong **foreground service** | WKWebView được **giữ trong `SessionManager`** (singleton), View chỉ "mượn" ra hiển thị |
| Số tin chưa đọc | đọc tiêu đề tab `"(3) Zalo"` qua `onReceivedTitle` | KVO trên `WKWebView.title`, regex `\((\d+)\)` |
| Bắt thông báo tin mới | hook `window.Notification` + `AndroidBridge` | cùng đoạn JS, đẩy qua `window.webkit.messageHandlers.zaloBridge` → `UNUserNotificationCenter` |
| Giữ đăng nhập | data-dir mỗi tiến trình vĩnh viễn | data store theo `forIdentifier:` được iOS lưu vĩnh viễn |

**Khác biệt nền tảng quan trọng:** Android giữ nhiều WebView **chạy nền vô thời hạn** bằng
foreground service. iOS **không cho** điều đó — khi app bị treo, JS/websocket Zalo Web dừng.
Bản iOS giám sát **tức thời** khi app đang mở / vừa chuyển nền; chạy nền sâu chỉ là
`BGAppRefreshTask` làm tươi số chưa đọc theo lịch của hệ điều hành (thưa, không tức thời).

---

## Yêu cầu

- **macOS + Xcode 15+** (bắt buộc để build iOS — không build được trên Windows).
- Thiết bị/Simulator **iOS 17.0+** (vì `WKWebsiteDataStore(forIdentifier:)`).
- Tài khoản Apple Developer (chạy trên máy thật cần ký; Simulator thì không).

> Bạn đang ở Windows: copy cả thư mục `ZaloGiamSat_IOS_Android` sang máy Mac rồi build ở đó,
> **hoặc** build trên cloud bằng GitHub Actions (xem mục "Build trên cloud" bên dưới — không
> cần máy Mac). Phần Android Kotlin vẫn build/chạy bình thường trên Windows này.

## Mở & chạy

**Cách A — XcodeGen (gọn nhất):**
```bash
brew install xcodegen      # nếu chưa có
cd ZaloGiamSat_IOS_Android
xcodegen generate          # tạo ZaloGiamSat.xcodeproj từ project.yml
open ZaloGiamSat.xcodeproj
# Chọn Team ký trong tab Signing & Capabilities → Run ▶
```

**Cách B — tạo project thủ công trong Xcode:**
1. Xcode → New → Project → **App** (Interface: SwiftUI, Language: Swift), tên `ZaloGiamSat`.
2. Đặt **Minimum Deployments = iOS 17.0**.
3. Xóa file mẫu, kéo toàn bộ thư mục `ZaloGiamSat/` (trừ `Info.plist` nếu Xcode đã tạo sẵn —
   khi đó copy các khóa từ `Info.plist` ở đây sang) vào project ("Create groups").
4. Vào **Signing & Capabilities** → thêm **Background Modes** → tick *Background fetch* và
   *Background processing*; đảm bảo `Info.plist` có `BGTaskSchedulerPermittedIdentifiers`
   chứa `com.zalogiamsat.ios.refresh` (đã có sẵn trong `Info.plist` kèm theo).
5. Chọn Team ký → Run ▶.

## Build trên cloud (không cần máy Mac)

Đã kèm sẵn workflow `.github/workflows/ios-build.yml`. Mỗi lần push code, GitHub dựng project
trên máy ảo macOS và **biên dịch** để bắt lỗi — đồng thời xuất bản `.app` (bản Simulator) tải về.

1. Tạo repo GitHub (để **public** sẽ được dùng máy ảo macOS miễn phí), rồi đẩy code lên:
   ```bash
   cd ZaloGiamSat_IOS_Android
   git init && git add . && git commit -m "Zalo Giám Sát iOS"
   git branch -M main
   git remote add origin https://github.com/<bạn>/<repo>.git
   git push -u origin main
   ```
2. Mở tab **Actions** trên GitHub → xem job **iOS Build** chạy. Xanh = code biên dịch OK.
3. Vào job → mục **Artifacts** → tải `ZaloGiamSat-sim-app` (chạy được trên iOS Simulator).

> ⚠️ Workflow này chỉ build cho **Simulator** (không ký) để xác minh biên dịch. Muốn ra file
> **.ipa cài lên iPhone thật** thì phải **ký** bằng tài khoản Apple Developer của bạn (cần thêm
> chứng chỉ + provisioning profile vào CI dạng Secrets, hoặc đơn giản nhất là mở project trên
> một máy Mac rồi Run thẳng vào iPhone). Đây là giới hạn ký của Apple, không phải của app.

## Tạo .ipa cài lên iPhone thật (ký bằng tài khoản của bạn)

Đã kèm `.github/workflows/ios-release.yml` + `ExportOptions.plist`: workflow **archive + ký +
xuất .ipa** trên máy ảo macOS, dùng chứng chỉ/hồ sơ của bạn nạp qua **GitHub Secrets** (mình
không giữ chứng chỉ của bạn).

> 💳 **Cần Apple Developer Program trả phí (~$99/năm)** để ký ad-hoc/phân phối ổn định trên CI.
> Tài khoản Apple miễn phí chỉ ký kiểu *development 7 ngày* và gần như phải làm trên máy Mac.

### Secret cần thêm (repo → Settings → Secrets and variables → Actions)
| Secret | Là gì |
|---|---|
| `APPLE_TEAM_ID` | Team ID 10 ký tự (Apple Developer → Membership) |
| `APP_BUNDLE_ID` | Bundle ID của bạn, vd `com.tencuaban.zalogiamsat` (khớp App ID của hồ sơ) |
| `DIST_CERT_P12_BASE64` | Chứng chỉ ký (.p12) đã base64 |
| `DIST_CERT_PASSWORD` | Mật khẩu khi xuất .p12 |
| `PROVISION_PROFILE_BASE64` | Hồ sơ provisioning (.mobileprovision) đã base64 |
| `PROVISION_PROFILE_NAME` | Tên hồ sơ (đúng như trên Developer portal) |

### Tạo chứng chỉ .p12 NGAY TRÊN WINDOWS (cần OpenSSL — không cần Mac)
```bash
openssl genrsa -out ios.key 2048
openssl req -new -key ios.key -out ios.csr -subj "/emailAddress=ban@email.com/CN=Ten Ban/C=VN"
```
1. https://developer.apple.com → Certificates → **+** → *Apple Distribution* (hoặc *iOS App
   Development*) → tải `ios.csr` lên → tải về file `.cer`.
2. Gộp .cer + khoá riêng thành .p12:
   ```bash
   openssl x509 -in distribution.cer -inform DER -out ios.pem -outform PEM
   openssl pkcs12 -export -inkey ios.key -in ios.pem -out cert.p12 -passout pass:MATKHAU
   ```
3. Tạo **App ID** (đúng `APP_BUNDLE_ID`) → **Devices** (đăng ký UDID iPhone của bạn) →
   **Profiles** tạo hồ sơ *Ad Hoc* (hoặc *Development*) gắn cert + device → tải `.mobileprovision`.
4. Base64 để dán vào Secret (PowerShell):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) | Set-Content p12.b64.txt
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Content prof.b64.txt
   ```
   `p12.b64.txt` → `DIST_CERT_P12_BASE64`; `prof.b64.txt` → `PROVISION_PROFILE_BASE64`.

### Chạy & cài
Actions → **iOS Release (signed IPA)** → *Run workflow* → chọn `method` = `ad-hoc` → tải `.ipa`
ở **Artifacts**. Cài lên iPhone bằng **Apple Configurator 2 / AltStore / Sideloadly**.

> ⚠️ Nếu đổi `APP_BUNDLE_ID`, sửa luôn `PRODUCT_BUNDLE_IDENTIFIER` trong `project.yml` cho khớp
> (mặc định `com.zalogiamsat.ios`).

## Cách dùng

1. Mở app → bấm **Tôi hiểu** ở lưu ý pháp lý → cho phép **Thông báo**.
2. Bấm **+** thêm tài khoản (đặt tên gợi nhớ) → chạm vào slot → **quét QR bằng app Zalo trên
   điện thoại có tài khoản đó**.
3. Quay lại dashboard: mỗi slot là một Zalo độc lập; "● Đang giám sát nền" + badge đỏ số chưa đọc.
4. **Nhấn giữ** (hoặc vuốt) một slot để: Mở · Đổi tên · Bật/Tắt giám sát nền · Xóa.
5. Menu **⋯** trong màn chat: *Tải lại* · **Lưu ảnh QR để đăng nhập** · *Đăng xuất (xóa phiên)*.
   - **Lưu ảnh QR**: tự bấm "Lấy mã mới" (nếu có) → chụp trang QR → lưu vào thư viện Ảnh. Sau đó
     mở app Zalo → Quét QR → chọn ảnh vừa lưu để đăng nhập **ngay trên cùng máy** (không cần điện
     thoại thứ 2). Lần đầu sẽ hỏi quyền **Thêm vào Ảnh** — bấm Cho phép.

## Cấu trúc thư mục

```
ZaloGiamSat_IOS_Android/
├── project.yml                         # XcodeGen spec
├── README.md
└── ZaloGiamSat/
    ├── Info.plist                      # background modes + BGTask id + quyền Ảnh
    ├── Assets.xcassets/                # AppIcon (1024) + LaunchLogo + LaunchBackground
    ├── ZaloGiamSatApp.swift            # @main, AppDelegate (BGAppRefreshTask), khởi động phiên
    ├── Core/Zalo.swift                 # URL, User-Agent, JS hook, parse/đếm chưa đọc, refresh QR
    ├── Models/Account.swift            # model (slot, name, enabled, dataStoreID)
    ├── Store/AccountStore.swift        # lưu tài khoản (UserDefaults + JSON)
    ├── Session/
    │   ├── ZaloSession.swift           # 1 WKWebView cô lập + đọc chưa đọc + bắt tin mới + lưu QR
    │   ├── SessionManager.swift        # giữ các phiên sống + gộp tổng chưa đọc + badge
    │   └── PhotoSaver.swift            # lưu ảnh QR vào thư viện Ảnh (quyền add-only)
    ├── Notifications/NotificationManager.swift   # thông báo tin mới + badge
    └── UI/
        ├── DashboardView.swift         # dashboard slot + thêm/sửa/xóa/bật-tắt + nút ⓘ
        ├── AccountWebViewScreen.swift  # vỏ hiển thị: "mượn" WebView + nút lưu QR
        └── GuideView.swift             # màn Hướng dẫn / Giới thiệu (cảnh báo pháp lý + cách dùng)
```

## Giới hạn đã biết

| Hạng mục | Ghi chú |
|---|---|
| Giám sát nền tức thời khi app đóng | **Không** (giới hạn iOS). Chỉ `BGAppRefreshTask` làm tươi thưa thớt. Muốn tức thời như Android cần Zalo hỗ trợ Web Push → APNs (hiện không có). |
| RAM | mỗi phiên giữ một WebContent process (~100–200 MB). Thực tế 4–6 tài khoản là hợp lý. |
| iOS < 17 | không hỗ trợ (thiếu API kho dữ liệu web theo định danh). |
| Zalo đổi giao diện web | có thể phải chỉnh `Zalo.parseUnread` / `unreadReporterJS` / `notifyHookJS`. Bộ đọc ưu tiên tiêu đề `(N)` (ổn định), dự phòng quét danh sách hội thoại; nếu đếm sai, gửi mình 1 ảnh Zalo Web đang có tin chưa đọc để chỉnh selector. |
| Quét QR ngay trên máy | thủ công — cần app Zalo ở thiết bị có tài khoản. |
| Lưu lịch sử chat | không làm (cân nhắc pháp lý). |

## Build cấu hình
- Swift 5 · SwiftUI · WKWebView · **Deployment target iOS 17.0**
- Background: `BGAppRefreshTask` id `com.zalogiamsat.ios.refresh`
