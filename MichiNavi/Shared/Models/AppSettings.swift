import Foundation

/// アプリ全体の設定を管理する
/// - 地図設定: UserDefaults に永続化
/// - お気に入り・踏破データ: NSUbiquitousKeyValueStore (iCloud KVS) に同期
@Observable
final class AppSettings {

    // MARK: - 地図タイル（UserDefaults）

    /// 選択中の地図タイル（デフォルト: Apple Maps）
    var selectedMapTile: MapTileType {
        didSet { UserDefaults.standard.set(selectedMapTile.rawValue, forKey: "selectedMapTile") }
    }

    /// Google Maps Tile API キー（空文字 = 未登録）
    var googleMapsAPIKey: String {
        didSet { UserDefaults.standard.set(googleMapsAPIKey, forKey: "googleMapsAPIKey") }
    }

    var hasGoogleMapsAPIKey: Bool { !googleMapsAPIKey.isEmpty }

    // MARK: - マーカー表示トグル（UserDefaults）

    /// 道の駅マーカーを地図上に表示するか
    var showStationMarkers: Bool {
        didSet { UserDefaults.standard.set(showStationMarkers, forKey: "showStationMarkers") }
    }

    /// カントリーサインマーカーを地図上に表示するか
    var showCountrySignMarkers: Bool {
        didSet { UserDefaults.standard.set(showCountrySignMarkers, forKey: "showCountrySignMarkers") }
    }

    // MARK: - お気に入り・踏破（iCloud KVS）

    /// お気に入り登録した道の駅 ID セット
    var favoriteStationIds: Set<String> {
        didSet { saveSync() }
    }

    /// 踏破済みとした道の駅 ID セット
    var visitedStationIds: Set<String> {
        didSet { saveSync() }
    }

    /// お気に入り登録したカントリーサイン（市町村コード）セット
    var favoriteSignIds: Set<String> {
        didSet { saveSync() }
    }

    /// 踏破済みとしたカントリーサイン（市町村コード）セット
    var visitedSignIds: Set<String> {
        didSet { saveSync() }
    }

    // MARK: - リスト→地図フォーカス（永続化なし）

    var mapFocusStation: RoadsideStation?
    var mapFocusSign: CountrySign?

    // MARK: - Toggle helpers

    func toggleFavorite(_ stationId: String) {
        if favoriteStationIds.contains(stationId) {
            favoriteStationIds.remove(stationId)
        } else {
            favoriteStationIds.insert(stationId)
        }
    }

    func toggleVisited(_ stationId: String) {
        if visitedStationIds.contains(stationId) {
            visitedStationIds.remove(stationId)
        } else {
            visitedStationIds.insert(stationId)
        }
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

    // MARK: - Init

    init() {
        let ud = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default

        // 地図設定は UserDefaults から
        let tileRaw = ud.string(forKey: "selectedMapTile") ?? MapTileType.appleMaps.rawValue
        self.selectedMapTile = MapTileType(rawValue: tileRaw) ?? .appleMaps
        self.googleMapsAPIKey = ud.string(forKey: "googleMapsAPIKey") ?? ""
        self.showStationMarkers = ud.object(forKey: "showStationMarkers") as? Bool ?? true
        self.showCountrySignMarkers = ud.object(forKey: "showCountrySignMarkers") as? Bool ?? true

        // KVS を同期してから読み込み（UserDefaults をフォールバックに使い既存データを移行）
        kvs.synchronize()

        let favArray = kvs.array(forKey: "favoriteStationIds") as? [String]
            ?? ud.stringArray(forKey: "favoriteStationIds") ?? []
        self.favoriteStationIds = Set(favArray)

        let visArray = kvs.array(forKey: "visitedStationIds") as? [String]
            ?? ud.stringArray(forKey: "visitedStationIds") ?? []
        self.visitedStationIds = Set(visArray)

        let favSignArray = kvs.array(forKey: "favoriteSignIds") as? [String]
            ?? ud.stringArray(forKey: "favoriteSignIds") ?? []
        self.favoriteSignIds = Set(favSignArray)

        let visSignArray = kvs.array(forKey: "visitedSignIds") as? [String]
            ?? ud.stringArray(forKey: "visitedSignIds") ?? []
        self.visitedSignIds = Set(visSignArray)
    }

    // MARK: - iCloud KVS 同期

    /// アプリがフォアグラウンドに復帰したときに呼び出す（他端末の変更を反映）
    func reloadFromKVS() {
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.synchronize()

        if let arr = kvs.array(forKey: "favoriteStationIds") as? [String] {
            favoriteStationIds = Set(arr)
        }
        if let arr = kvs.array(forKey: "visitedStationIds") as? [String] {
            visitedStationIds = Set(arr)
        }
        if let arr = kvs.array(forKey: "favoriteSignIds") as? [String] {
            favoriteSignIds = Set(arr)
        }
        if let arr = kvs.array(forKey: "visitedSignIds") as? [String] {
            visitedSignIds = Set(arr)
        }
    }

    // MARK: - Private persist

    private func saveSync() {
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(Array(favoriteStationIds), forKey: "favoriteStationIds")
        kvs.set(Array(visitedStationIds), forKey: "visitedStationIds")
        kvs.set(Array(favoriteSignIds), forKey: "favoriteSignIds")
        kvs.set(Array(visitedSignIds), forKey: "visitedSignIds")
        kvs.synchronize()
    }
}
