import Foundation
import WebKit

/// Lưu/khôi phục cookie theo từng tài khoản (giữ đăng nhập Zalo Web trên iOS 16, nơi không có
/// kho dữ liệu web bền theo định danh như iOS 17). Best-effort: phần lớn phiên Zalo nằm ở cookie.
enum CookieStore {
    private static func fileURL(_ id: UUID) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cookies-\(id.uuidString).dat")
    }

    static func save(_ cookies: [HTTPCookie], for id: UUID) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true)
        else { return }
        try? data.write(to: fileURL(id))
    }

    static func load(for id: UUID) -> [HTTPCookie] {
        guard let data = try? Data(contentsOf: fileURL(id)),
              let arr = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, HTTPCookie.self], from: data) as? [HTTPCookie]
        else { return [] }
        return arr
    }

    static func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(id))
    }
}
