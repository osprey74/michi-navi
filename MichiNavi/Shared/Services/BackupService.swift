import Foundation

// MARK: - バックアップデータ構造

struct BackupData: Codable {
    let version: Int
    let exportedAt: Date
    let favoriteStationIds: [String]
    let visitedStationIds: [String]
    let favoriteSignIds: [String]
    let visitedSignIds: [String]
}

// MARK: - バックアップサービス

enum BackupService {

    // MARK: エクスポート

    /// AppSettings の お気に入り・踏破データを JSON ファイルとして一時ディレクトリに書き出し、そのURLを返す
    static func export(settings: AppSettings) throws -> URL {
        let backup = BackupData(
            version: 1,
            exportedAt: Date(),
            favoriteStationIds: Array(settings.favoriteStationIds),
            visitedStationIds: Array(settings.visitedStationIds),
            favoriteSignIds: Array(settings.favoriteSignIds),
            visitedSignIds: Array(settings.visitedSignIds)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "michinavi_backup_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: インポート

    /// JSON ファイルの内容を AppSettings に復元する
    static func restore(from url: URL, into settings: AppSettings) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)

        settings.favoriteStationIds = Set(backup.favoriteStationIds)
        settings.visitedStationIds  = Set(backup.visitedStationIds)
        settings.favoriteSignIds    = Set(backup.favoriteSignIds)
        settings.visitedSignIds     = Set(backup.visitedSignIds)
    }
}
