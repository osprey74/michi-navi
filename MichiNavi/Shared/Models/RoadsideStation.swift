import Foundation
import CoreLocation

/// 道の駅データモデル
struct RoadsideStation: Codable, Identifiable, Sendable {

    let id: String
    let name: String
    let prefecture: String?
    let municipality: String?
    let latitude: Double
    let longitude: Double
    let roadName: String?
    let features: [String]
    let url: String?
    let imageUrl: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, prefecture, municipality, latitude, longitude
        case roadName = "road_name"
        case features, url
        case imageUrl = "image_url"
    }
}

// MARK: - 施設設備情報

extension RoadsideStation {

    /// 施設設備の表示用情報
    struct FeatureInfo: Sendable {
        let key: String
        let label: String
        let icon: String  // SF Symbol名
    }

    /// features キーと表示用ラベル・アイコンのマッピング
    static let featureMap: [String: (label: String, icon: String)] = [
        "atm": ("ATM", "banknote"),
        "restaurant": ("レストラン", "fork.knife"),
        "onsen": ("温泉", "drop.fill"),
        "ev_charger": ("EV充電", "ev.charger"),
        "wifi": ("Wi-Fi", "wifi"),
        "baby_room": ("授乳室", "figure.and.child.holdinghands"),
        "disabled_toilet": ("障害者トイレ", "figure.roll"),
        "information": ("情報コーナー", "info.circle"),
        "shop": ("物販", "bag"),
        "experience": ("体験施設", "hands.sparkles"),
        "museum": ("資料館", "building.columns"),
        "park": ("公園", "tree"),
        "hotel": ("宿泊", "bed.double"),
        "rv_park": ("RVパーク", "car.side"),
        "dog_run": ("ドッグラン", "dog"),
        "bicycle_rental": ("レンタサイクル", "bicycle"),
        "camping": ("キャンプ", "tent"),
        "footbath": ("足湯", "figure.pool.swim"),
    ]

    /// features 配列から表示用 FeatureInfo 配列を生成
    var featureInfos: [FeatureInfo] {
        features.compactMap { key in
            guard let info = Self.featureMap[key] else {
                return FeatureInfo(key: key, label: key, icon: "questionmark.circle")
            }
            return FeatureInfo(key: key, label: info.label, icon: info.icon)
        }
    }
}

/// 検索結果として距離・方位付きの道の駅
struct NearbyStation: Identifiable, Sendable {
    let station: RoadsideStation
    let distanceKm: Double
    let bearing: Double

    var id: String { station.id }

    /// 16方位の方角文字列
    var cardinalDirection: String {
        GeoUtils.cardinalDirection(from: bearing)
    }

    /// 距離の表示文字列
    var distanceText: String {
        if distanceKm < 1 {
            return String(format: "%.0f m", distanceKm * 1000)
        }
        return String(format: "%.1f km", distanceKm)
    }
}
