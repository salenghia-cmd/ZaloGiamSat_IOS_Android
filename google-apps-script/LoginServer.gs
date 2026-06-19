/**
 * MÁY CHỦ ĐĂNG NHẬP cho app Zalo Giám Sát (Google Apps Script gắn với Google Sheet).
 * App gửi { phone, key } -> script tra trong sheet -> trả JSON { ok, reason, expiry }.
 * Sheet GIỮ RIÊNG TƯ (script chạy bằng quyền của bạn).
 *
 * Cột sheet (hàng 1 là tiêu đề):
 *   A: SoDienThoai | B: MaKichHoat | C: KichHoat (TRUE/FALSE) | D: HanDung (yyyy-mm-dd, trống = vô hạn)
 *
 * CÁCH DÙNG:
 *   1) Mở Google Sheet -> Extensions (Tiện ích) -> Apps Script
 *   2) Xóa code mẫu, dán toàn bộ file này -> Save
 *   3) Deploy -> New deployment -> type "Web app" -> Execute as: Me, Who has access: Anyone -> Deploy
 *   4) Authorize (cấp quyền) -> copy "Web app URL" (.../exec) gửi cho dev để gắn vào app
 */

function doPost(e) { return handle(e); }
function doGet(e)  { return handle(e); } // cho phép mở bằng trình duyệt để test

function handle(e) {
  var out = { ok: false, reason: "UNKNOWN" };
  try {
    var p = (e && e.parameter) ? e.parameter : {};
    var phone = String(p.phone || "").trim();
    var key   = String(p.key   || "").trim();
    if (!phone || !key) { out.reason = "MISSING"; return json(out); }

    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
    var data  = sheet.getDataRange().getValues();

    for (var i = 1; i < data.length; i++) {            // bỏ hàng tiêu đề
      var rPhone = String(data[i][0]).trim();
      if (rPhone !== phone) continue;

      var rKey = String(data[i][1]).trim();
      if (rKey !== key) { out.reason = "WRONG_KEY"; return json(out); }

      var active = data[i][2];
      var on = (active === true) ||
               (String(active).toUpperCase() === "TRUE") ||
               (String(active) === "1") ||
               (String(active).toLowerCase() === "x");
      if (!on) { out.reason = "DISABLED"; return json(out); }

      var han = data[i][3];
      if (han !== "" && han !== null && han !== undefined) {
        var d = (han instanceof Date) ? han : new Date(han);
        if (!isNaN(d.getTime())) {
          out.expiry = Utilities.formatDate(d, "GMT+7", "yyyy-MM-dd");
          if (d.getTime() < Date.now()) { out.reason = "EXPIRED"; return json(out); }
        } else {
          out.expiry = String(han);
        }
      }

      out.ok = true; out.reason = "OK";
      return json(out);
    }

    out.reason = "NOT_FOUND";
    return json(out);
  } catch (err) {
    out.reason = "ERR:" + err;
    return json(out);
  }
}

function json(o) {
  return ContentService
    .createTextOutput(JSON.stringify(o))
    .setMimeType(ContentService.MimeType.JSON);
}
