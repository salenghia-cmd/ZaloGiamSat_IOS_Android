# Cài app lên iPhone — KHÔNG cần Mac, KHÔNG cần tài khoản trả phí

App này chỉ dùng thông báo nội bộ + WebView (không push từ xa, không iCloud) nên **sideload
bằng Apple ID miễn phí là chạy được**. Hạn chế của Apple ID free: app **hết hạn sau 7 ngày**
→ cài lại là xong (hoặc dùng AltStore để tự gia hạn).

> 📱 iPhone cần **iOS 17 trở lên** (app cô lập phiên Zalo dùng API của iOS 17).

---

## Bước 1 — Lấy file .ipa (từ GitHub Actions)
1. Vào repo → tab **Actions** → mở lần chạy **iOS Build** mới nhất (dấu ✓ xanh).
2. Kéo xuống mục **Artifacts** → tải **`ZaloGiamSat-unsigned-ipa`** về máy.
3. Giải nén ra file **`ZaloGiamSat-unsigned.ipa`**.

## Bước 2 — Cài Sideloadly + iTunes/iCloud (chỉ làm 1 lần)
1. Cài **iTunes** và **iCloud** **bản tải từ apple.com** (KHÔNG dùng bản Microsoft Store — Sideloadly không nhận bản Store).
2. Tải **Sideloadly**: https://sideloadly.io → cài.

## Bước 3 — Sideload
1. Cắm iPhone vào PC bằng cáp → mở khoá iPhone → bấm **Trust / Tin cậy máy tính này**.
2. Mở **Sideloadly**:
   - Kéo thả file `ZaloGiamSat-unsigned.ipa` vào ô **IPA**.
   - **Apple Account**: nhập **Apple ID** của bạn (free cũng được).
   - Bấm **Start**.
3. Nếu Apple ID bật 2 lớp (2FA): Sideloadly sẽ hỏi mã → mở iPhone lấy mã 6 số nhập vào.
   *(Hoặc tạo app-specific password tại appleid.apple.com nếu nó yêu cầu.)*
4. Đợi tới khi báo **Done**.

## Bước 4 — Tin cậy app trên iPhone
1. Trên iPhone: **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị** (Settings → General → VPN & Device Management).
2. Bấm vào hồ sơ developer mang **Apple ID của bạn** → **Tin cậy (Trust)**.
3. Về màn hình chính, mở app **Zalo Giám Sát** → cấp quyền **Thông báo** khi được hỏi.

## Dùng app
- Bấm **+** thêm Zalo → mở slot → quét QR bằng app Zalo trên điện thoại có tài khoản đó
  (hoặc menu **⋯ → Lưu ảnh QR** rồi mở Zalo quét ảnh ngay trên máy).

---

## Khi app hết hạn (sau ~7 ngày)
Apple ID free ký app chỉ sống 7 ngày. Hết hạn (mở app báo lỗi) thì:
- **Cách đơn giản:** cắm iPhone, mở Sideloadly, sideload lại file .ipa như Bước 3.
- **Cách tự động (đỡ phải nhớ):** dùng **AltStore** + **AltServer** (https://altstore.io) trên
  Windows — nó tự gia hạn 7 ngày/lần **khi PC bật và cùng Wi-Fi với iPhone**. Cài AltStore xong,
  mở file .ipa bằng AltStore để cài.

## Giới hạn của Apple ID free (Apple quy định, không phải lỗi app)
- App hết hạn sau **7 ngày**.
- Tối đa **3 app** sideload cùng lúc / 1 Apple ID free.
- Mỗi 7 ngày đăng ký được giới hạn số App ID.
- Muốn khỏi các giới hạn này (app sống 1 năm) thì cần **Apple Developer Program trả phí** —
  lúc đó dùng workflow **iOS Release** + script `scripts\tao-chung-chi-ios.cmd` (xem README).
