import UIKit

/// 道の駅・カントリーサインのフォトアルバムを管理するサービス
///
/// - iCloud が利用可能な場合: `<ubiquityContainer>/Documents/Albums/<albumId>/photo_1.jpg` に保存
/// - iCloud が利用不可の場合: `<ApplicationSupport>/Albums/<albumId>/photo_1.jpg` に保存（フォールバック）
/// - アプリ起動時にバックグラウンドで iCloud コンテナ URL を解決し、既存のローカル写真を移行する
/// - 道の駅: `albumId = station.id`、カントリーサイン: `albumId = "sign_\(sign.id)"`
@Observable
final class StationPhotoStore {

    static let maxPhotos = 3
    private let maxDimension: CGFloat = 1024
    private let jpegQuality: CGFloat = 0.72

    /// 現在の写真保存先ベース URL（iCloud 解決後に更新される）
    private(set) var baseURL: URL
    private let localBaseURL: URL

    init() {
        let local = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Albums")
        self.localBaseURL = local
        self.baseURL = local

        // バックグラウンドで iCloud コンテナ URL を解決し、解決できれば baseURL を更新する
        Task { [weak self] in
            guard let self else { return }
            let cloudURL: URL? = await Task.detached(priority: .utility) {
                FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                    .appendingPathComponent("Documents/Albums")
            }.value

            guard let cloudURL else { return }

            // baseURL の更新は MainActor 上で行う
            await MainActor.run { self.baseURL = cloudURL }

            // ローカルに残っている写真を iCloud コンテナへ移行（バックグラウンド）
            await Task.detached(priority: .utility) {
                StationPhotoStore.migrateLocalToCloud(from: local, to: cloudURL)
            }.value
        }
    }

    // MARK: - iCloud 移行

    /// ローカルの Albums ディレクトリ以下のファイルを iCloud コンテナへ移動する
    private static func migrateLocalToCloud(from local: URL, to cloud: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: local.path) else { return }

        let albumDirs = (try? fm.contentsOfDirectory(
            at: local,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []

        for dir in albumDirs {
            let destDir = cloud.appendingPathComponent(dir.lastPathComponent)
            // 移行先にすでにディレクトリがあればスキップ
            guard !fm.fileExists(atPath: destDir.path) else { continue }
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files {
                let dest = destDir.appendingPathComponent(file.lastPathComponent)
                guard !fm.fileExists(atPath: dest.path) else { continue }
                try? fm.moveItem(at: file, to: dest)
            }
        }
    }

    // MARK: - Paths

    private func albumDirectory(for albumId: String) -> URL {
        baseURL.appendingPathComponent(albumId, isDirectory: true)
    }

    private func photoURL(slot: Int, albumId: String) -> URL {
        albumDirectory(for: albumId).appendingPathComponent("photo_\(slot + 1).jpg")
    }

    // MARK: - Public API

    /// 指定 albumId の写真を 3 スロット分返す（空・未ダウンロードスロットは nil）
    func loadPhotos(for albumId: String) -> [UIImage?] {
        (0..<Self.maxPhotos).map { slot in
            let url = photoURL(slot: slot, albumId: albumId)
            // iCloud 上にあるが未ダウンロードのファイルはダウンロードをトリガーして nil を返す
            // 次回 onAppear 時に reload されると写真が表示される
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    /// 写真をリサイズして指定スロットに保存する（JPEG, maxDimension=1024, quality=0.72）
    func savePhoto(_ image: UIImage, at slot: Int, for albumId: String) throws {
        let dir = albumDirectory(for: albumId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let resized = image.resized(maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return }
        try data.write(to: photoURL(slot: slot, albumId: albumId))
    }

    /// 指定スロットの写真ファイルを削除する
    func deletePhoto(at slot: Int, for albumId: String) {
        try? FileManager.default.removeItem(at: photoURL(slot: slot, albumId: albumId))
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
