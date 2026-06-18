# Bắt đầu nhanh — đưa app lên iPhone

> ⚠️ Build/cài iOS **bắt buộc** qua macOS. Có 2 đường: **(A)** GitHub Actions (không cần máy Mac)
> hoặc **(B)** máy Mac + Xcode. Bước đánh dấu **[Bạn]** là việc chỉ bạn làm được (tài khoản
> Apple/GitHub, cắm iPhone). Mình đã chuẩn bị sẵn mọi thứ còn lại.

---

## A. Không cần máy Mac — build & ký trên GitHub Actions

**1. [Bạn] Đẩy code lên GitHub** (tạo 1 repo trống, để **Public** cho macOS runner miễn phí):
```bash
cd "D:/Chuong_Trinh_Computer/DienThoaiKetNoiMayTinh/ZALO/ZaloGiamSat_IOS_Android"
git remote add origin https://github.com/<tên-bạn>/<tên-repo>.git
git push -u origin main
```

**2. Kiểm tra biên dịch (tự động):** mở tab **Actions** → job **iOS Build** chạy → **xanh = code
biên dịch OK**. (Đây là khâu "build" thật, thay cho việc không build được trên Windows.)

**3. [Bạn] Chuẩn bị chứng chỉ ký** (cần **Apple Developer Program trả phí ~$99/năm**):
- Bấm đôi **`scripts\tao-chung-chi-ios.cmd`** → làm theo hướng dẫn trên màn hình:
  tạo `ios.csr` → upload lên developer.apple.com → tải `.cer` + `.mobileprovision` về thư mục
  `signing\` → chạy lại script để ra `cert.p12` + base64 + file **`signing\SECRETS-de-dan.txt`**.

**4. [Bạn] Thêm 6 Secret** vào repo (Settings → Secrets and variables → Actions): chép đúng theo
`signing\SECRETS-de-dan.txt`.

**5. Xuất .ipa:** Actions → **iOS Release (signed IPA)** → *Run workflow* → `method = ad-hoc`
→ tải `.ipa` ở **Artifacts**.

**6. [Bạn] Cài lên iPhone:** dùng **AltStore**, **Sideloadly**, hoặc **Apple Configurator 2**.

> Tài khoản Apple **miễn phí** không ký ad-hoc/CI ổn định được → hãy đi đường **B** (Mac + Xcode,
> ký *development* 7 ngày).

---

## B. Có máy Mac

```bash
brew install xcodegen
cd ZaloGiamSat_IOS_Android
xcodegen generate
open ZaloGiamSat.xcodeproj
```
Trong Xcode: chọn **Team** ở *Signing & Capabilities* → cắm iPhone → bấm **Run ▶**. Xong.

---

## Vì sao có những bước "[Bạn]"?
- **Push GitHub** = đẩy mã nguồn lên tài khoản của bạn (cần đăng nhập của bạn, là hành động
  công khai code) → bạn tự quyết & tự chạy.
- **Tài khoản Apple + chứng chỉ** = danh tính ký của bạn, mình không thể (và không nên) giữ.
- **Cài lên iPhone** = cần thiết bị thật của bạn.

Mọi thứ khác (code app, project, CI build/ký, icon, script tạo chứng chỉ) đã sẵn trong repo.
