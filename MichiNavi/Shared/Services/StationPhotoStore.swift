import UIKit

/// 道の駅フォトアルバムの保存・読み込み・削除を管理するサービス
///
/// 写真は `{applicationSupport}/Albums/{stationId}/photo_{1-3}.jpg` に保存される。
/// ファイルパスが固定のため CoreData 不要 — ファイル存在チェックのみで管理する。
final class StationPhotoStore {

    static let maxPhotos = 3
    private let maxDimension: CGFloat = 1024
    private let jpegQuality: CGFloat = 0.72

    // MARK: - Paths

    private func albumDirectory(for stationId: String) -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportDir.appendingPathComponent("Albums/\(stationId)", isDirectory: true)
    }

    private func photoURL(slot: Int, stationId: String) -> URL {
        albumDirectory(for: stationId).appendingPathComponent("photo_\(slot + 1).jpg")
    }

    // MARK: - Public API

    /// 指定 stationId の写真を3スロット分返す（空スロットは nil）
    func loadPhotos(for stationId: String) -> [UIImage?] {
        return (0..<Self.maxPhotos).map { slot in
            let url = photoURL(slot: slot, stationId: stationId)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    /// 写真をリサイズして指定スロットに保存する（JPEG, maxDimension=1024, quality=0.72）
    func savePhoto(_ image: UIImage, at slot: Int, for stationId: String) throws {
        let dir = albumDirectory(for: stationId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let resized = image.resized(maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return }
        try data.write(to: photoURL(slot: slot, stationId: stationId))
    }

    /// 指定スロットの写真ファイルを削除する
    func deletePhoto(at slot: Int, for stationId: String) {
        let url = photoURL(slot: slot, stationId: stationId)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
