import Foundation

/// アプリ全体の設定を管理する
/// UserDefaults に永続化し、@Observable で UI に反映
@Observable
final class AppSettings {

    // MARK: - 地図タイル

    /// 選択中の地図タイル（デフォルト: 国土地理院 淡色）
    var selectedMapTile: MapTileType {
        didSet { save() }
    }

    /// Google Maps Tile API キー（空文字 = 未登録）
    var googleMapsAPIKey: String {
        didSet { save() }
    }

    var hasGoogleMapsAPIKey: Bool { !googleMapsAPIKey.isEmpty }

    // MARK: - お気に入り・到達

    /// お気に入り登録した道の駅 ID セット
    var favoriteStationIds: Set<String> {
        didSet { save() }
    }

    /// 到達済みとした道の駅 ID セット
    var visitedStationIds: Set<String> {
        didSet { save() }
    }

    func toggleFavorite(_ stationId: String) {
        if favoriteStationIds.contains(stationId) {
            favoriteStationIds.remove(stationId)
        } else {
            favoriteStationIds.insert(stationId)
        }
    }

    // MARK: - リスト→地図フォーカス（永続化なし）

    /// リストから詳細を閲覧した道の駅（シート閉じ時に地図を移動するために使用）
    var mapFocusStation: RoadsideStation?

    func toggleVisited(_ stationId: String) {
        if visitedStationIds.contains(stationId) {
            visitedStationIds.remove(stationId)
        } else {
            visitedStationIds.insert(stationId)
        }
    }

    // MARK: - Init / Persist

    init() {
        let ud = UserDefaults.standard

        let tileRaw = ud.string(forKey: "selectedMapTile") ?? MapTileType.appleMaps.rawValue
        self.selectedMapTile = MapTileType(rawValue: tileRaw) ?? .appleMaps

        self.googleMapsAPIKey = ud.string(forKey: "googleMapsAPIKey") ?? ""

        let favArray = ud.stringArray(forKey: "favoriteStationIds") ?? []
        self.favoriteStationIds = Set(favArray)

        let visArray = ud.stringArray(forKey: "visitedStationIds") ?? []
        self.visitedStationIds = Set(visArray)
    }

    private func save() {
        let ud = UserDefaults.standard
        ud.set(selectedMapTile.rawValue, forKey: "selectedMapTile")
        ud.set(googleMapsAPIKey, forKey: "googleMapsAPIKey")
        ud.set(Array(favoriteStationIds), forKey: "favoriteStationIds")
        ud.set(Array(visitedStationIds), forKey: "visitedStationIds")
    }
}
