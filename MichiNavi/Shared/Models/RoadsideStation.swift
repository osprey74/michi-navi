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
