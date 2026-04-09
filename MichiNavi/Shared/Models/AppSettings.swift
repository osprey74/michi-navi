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

    // MARK: - カントリーサイン お気に入り・踏破

    /// お気に入り登録したカントリーサイン（市町村コード）セット
    var favoriteSignIds: Set<String> {
        didSet { save() }
    }

    /// 踏破済みとしたカントリーサイン（市町村コード）セット
    var visitedSignIds: Set<String> {
        didSet { save() }
    }

    func toggleSignFavorite(_ signId: String) {
        if favoriteSignIds.contains(signId) {
            favoriteSignIds.remove(signId)
        } else {
            favoriteSignIds.insert(signId)
        }
    }

    func toggleSignVisited(_ signId: String) {
        if visitedSignIds.contains(signId) {
            visitedSignIds.remove(signId)
        } else {
            visitedSignIds.insert(signId)
        }
    }

    // MARK: - マーカー表示トグル

    /// 道の駅マーカーを地図上に表示するか
    var showStationMarkers: Bool {
        didSet { save() }
    }

    /// カントリーサインマーカーを地図上に表示するか
    var showCountrySignMarkers: Bool {
        didSet { save() }
    }

    // MARK: - リスト→地図フォーカス（永続化なし）

    /// リストから詳細を閲覧した道の駅（シート閉じ時に地図を移動するために使用）
    var mapFocusStation: RoadsideStation?

    /// リストから詳細を閲覧したカントリーサイン（シート閉じ時に地図を移動するために使用）
    var mapFocusSign: CountrySign?

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

        let favSignArray = ud.stringArray(forKey: "favoriteSignIds") ?? []
        self.favoriteSignIds = Set(favSignArray)

        let visSignArray = ud.stringArray(forKey: "visitedSignIds") ?? []
        self.visitedSignIds = Set(visSignArray)

        self.showStationMarkers = ud.object(forKey: "showStationMarkers") as? Bool ?? true
        self.showCountrySignMarkers = ud.object(forKey: "showCountrySignMarkers") as? Bool ?? true
    }

    private func save() {
        let ud = UserDefaults.standard
        ud.set(selectedMapTile.rawValue, forKey: "selectedMapTile")
        ud.set(googleMapsAPIKey, forKey: "googleMapsAPIKey")
        ud.set(Array(favoriteStationIds), forKey: "favoriteStationIds")
        ud.set(Array(visitedStationIds), forKey: "visitedStationIds")
        ud.set(Array(favoriteSignIds), forKey: "favoriteSignIds")
        ud.set(Array(visitedSignIds), forKey: "visitedSignIds")
        ud.set(showStationMarkers, forKey: "showStationMarkers")
        ud.set(showCountrySignMarkers, forKey: "showCountrySignMarkers")
    }
}
