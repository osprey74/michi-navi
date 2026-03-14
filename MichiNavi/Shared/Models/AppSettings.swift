import Foundation

/// アプリ全体の設定を管理する
/// UserDefaults に永続化し、@Observable で UI に反映
@Observable
final class AppSettings {

    /// ズームボタンの表示位置
    enum ZoomPosition: String, CaseIterable {
        case left = "left"
        case right = "right"

        var label: String {
            switch self {
            case .left: return "左側"
            case .right: return "右側"
            }
        }
    }

    /// ズームボタンの表示位置（デフォルト: 右側）
    var zoomPosition: ZoomPosition {
        didSet { save() }
    }

    /// 道の駅検索範囲（km）— 50〜400、デフォルト100
    var searchRadiusKm: Double {
        didSet { save() }
    }

    /// POI表示: ガソリンスタンド
    var showGasStations: Bool {
        didSet { save() }
    }

    /// POI表示: コンビニ・スーパー
    var showFoodMarkets: Bool {
        didSet { save() }
    }

    /// POI表示: レストラン
    var showRestaurants: Bool {
        didSet { save() }
    }

    /// POI表示: 駐車場
    var showParking: Bool {
        didSet { save() }
    }

    /// POI表示: RVパーク・キャンプ場
    var showRVParks: Bool {
        didSet { save() }
    }

    /// 検索範囲距離から地図の緯度スパン（度）を算出
    /// 画面短辺に収まるよう、距離をスパンとして設定
    var searchRadiusLatitudeDelta: Double {
        // 1km ≈ 0.009度（緯度）
        return searchRadiusKm * 0.009
    }

    /// いずれかのPOIカテゴリが有効か
    var hasAnyPOIEnabled: Bool {
        showGasStations || showFoodMarkets || showRestaurants || showParking
    }

    init() {
        let ud = UserDefaults.standard
        let stored = ud.string(forKey: "zoomPosition") ?? "right"
        self.zoomPosition = ZoomPosition(rawValue: stored) ?? .right
        self.searchRadiusKm = ud.object(forKey: "searchRadiusKm") as? Double ?? 100
        self.showGasStations = ud.object(forKey: "showGasStations") as? Bool ?? true
        self.showFoodMarkets = ud.object(forKey: "showFoodMarkets") as? Bool ?? false
        self.showRestaurants = ud.object(forKey: "showRestaurants") as? Bool ?? false
        self.showParking = ud.object(forKey: "showParking") as? Bool ?? false
        self.showRVParks = ud.object(forKey: "showRVParks") as? Bool ?? true
    }

    private func save() {
        let ud = UserDefaults.standard
        ud.set(zoomPosition.rawValue, forKey: "zoomPosition")
        ud.set(searchRadiusKm, forKey: "searchRadiusKm")
        ud.set(showGasStations, forKey: "showGasStations")
        ud.set(showFoodMarkets, forKey: "showFoodMarkets")
        ud.set(showRestaurants, forKey: "showRestaurants")
        ud.set(showParking, forKey: "showParking")
        ud.set(showRVParks, forKey: "showRVParks")
    }
}
