import Photos
import UIKit

/// Lưu ảnh vào thư viện Ảnh, chỉ xin quyền THÊM ảnh (add-only) — không đọc thư viện của người dùng.
enum PhotoSaver {
    static func save(_ image: UIImage) async -> Bool {
        let status: PHAuthorizationStatus = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { cont.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else { return false }

        return await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            } completionHandler: { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }
}
