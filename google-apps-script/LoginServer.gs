/**
 * MÁY CHỦ ĐĂNG NHẬP + LICENSE cho app Zalo Giám Sát (Android & iOS dùng CHUNG).
 * App gọi:  GET .../exec?phone=&key=&device=&platform=&model=&os=&appver=
 *           GET .../exec?action=ping&phone=&event=online&platform=&model=&os=&appver=
 *           GET .../exec?action=config
 *
 * Cột sheet (License = sheet đầu tiên):
 *  A SDT | B KEY | C NGAYHETHAN | D MATHIETBI | E GHICHU | F LAST_SEEN | G STATUS |
 *  H TRANG_THAI | I SOZALO | J PLATFORM | K MODEL | L OS | M APP_VER
 *
 * Cập nhật code này: dán đè vào Apps Script -> Lưu -> Triển khai -> QUẢN LÝ bản triển khai
 * -> sửa (bút chì) -> Phiên bản: Phiên bản mới -> Triển khai  (GIỮ NGUYÊN link /exec cũ).
 */

var SHEET_ID = '16ONkjgLDXnW1kNMdD5GhaZl6beSDqrGJgF5kHAjP9ew';

function doGet(e)  { return handle(e); }
function doPost(e) { return handle(e); }

function handle(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  var out;
  try {
    if (p.action === 'config') out = getConfig();
    else if (p.action === 'ping') out = ping((p.phone || '').trim(), (p.event || 'online').trim(), p);
    else out = check((p.phone || '').trim(), (p.key || '').trim(), (p.device || '').trim(), p);
  } catch (err) {
    out = { ok: false, reason: 'ERROR' };
  }
  return ContentService.createTextOutput(JSON.stringify(out))
    .setMimeType(ContentService.MimeType.JSON);
}

function sheet() {
  var ss = SpreadsheetApp.openById(SHEET_ID);
  return ss.getSheetByName('License') || ss.getSheets()[0];
}

function getConfig() {
  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName('Config');
  var cfg = {};
  if (sh) {
    var d = sh.getDataRange().getValues();
    for (var i = 0; i < d.length; i++) {
      var k = String(d[i][0] || '').trim();
      if (k) cfg[k] = String(d[i][1] || '');
    }
  }
  return { ok: true, config: cfg };
}

function normPhone(s) { return String(s).replace(/\D/g, '').replace(/^0+/, ''); }

/** Ghi LAST_SEEN + thông tin máy (telemetry) cho 1 hàng. row = số hàng thật (1-based). */
function setInfo(sh, row, p) {
  try {
    sh.getRange(row, 6).setValue(new Date());                       // F = LAST_SEEN
    if (p && p.platform) sh.getRange(row, 10).setValue(p.platform); // J = PLATFORM (iOS/Android)
    if (p && p.model)    sh.getRange(row, 11).setValue(p.model);    // K = MODEL (vd iPhone10,3)
    if (p && p.os)       sh.getRange(row, 12).setValue(p.os);       // L = OS (vd 16.7.10)
    if (p && p.appver)   sh.getRange(row, 13).setValue(p.appver);   // M = APP_VER
  } catch (e) {}
}

function ping(phone, event, p) {
  if (!phone) return { ok: false, reason: 'EMPTY' };
  var sh = sheet(); var data = sh.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (normPhone(data[i][0]) === normPhone(phone)) {
      setInfo(sh, i + 1, p);
      sh.getRange(i + 1, 7).setValue(event || 'online'); // G = STATUS
      return { ok: true };
    }
  }
  return { ok: false, reason: 'WRONG' };
}

function check(phone, key, device, p) {
  if (!phone || !key) return { ok: false, reason: 'EMPTY' };
  var sh = sheet(); var data = sh.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    var r = data[i];
    if (normPhone(r[0]) === normPhone(phone) && String(r[1]).trim() === String(key).trim()) {
      var exp = (r[2] instanceof Date) ? r[2] : new Date(r[2]);
      var today = new Date(); today.setHours(0, 0, 0, 0);
      var end = new Date(exp); end.setHours(23, 59, 59, 999);
      if (end < today) return { ok: false, reason: 'EXPIRED', expiry: fmt(exp) };

      var bound = String(r[3] || '').trim();
      if (!bound) sh.getRange(i + 1, 4).setValue(device);                 // D: tự gắn máy đầu tiên
      else if (bound !== device) return { ok: false, reason: 'OTHER_DEVICE', expiry: fmt(exp) };

      setInfo(sh, i + 1, p);                                              // ghi telemetry khi đăng nhập OK
      return { ok: true, expiry: fmt(exp), max: (parseInt(r[8], 10) || 5) };
    }
  }
  return { ok: false, reason: 'WRONG' };
}

function fmt(d) {
  d = (d instanceof Date) ? d : new Date(d);
  return Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
}
