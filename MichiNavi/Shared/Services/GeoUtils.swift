import Foundation
import CoreLocation

/// 地理計算ユーティリティ（raspberry-pi 版 geo_utils.py の Swift 移植）
enum GeoUtils {

    private static let earthRadiusKm: Double = 6371.0

    /// Haversine 公式による2点間の大圏距離 (km)
    static func haversine(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let dLat = (to.latitude - from.latitude).radians
        let dLon = (to.longitude - from.longitude).radians

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }

    /// 2点間の初期方位角 (0–360°、北=0、時計回り)
    static func bearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let dLon = (to.longitude - from.longitude).radians

        let x = sin(dLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let rad = atan2(x, y)
        return (rad.degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// 進行方向の前方コーン内にあるか判定
    /// - Parameters:
    ///   - heading: 車両の進行方向 (0–360°)
    ///   - bearingToTarget: 目標への方位角 (0–360°)
    ///   - threshold: 前方コーンの半角 (デフォルト 45°)
    static func isAhead(
        heading: Double,
        bearingToTarget: Double,
        threshold: Double = 45
    ) -> Bool {
        var diff = bearingToTarget - heading
        // -180〜180 に正規化
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return abs(diff) <= threshold
    }

    /// 方位角から 16 方位の文字列に変換
    static func cardinalDirection(from bearing: Double) -> String {
        let cardinals = [
            "N", "NNE", "NE", "ENE",
            "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW",
            "W", "WNW", "NW", "NNW"
        ]
        let index = Int((bearing + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return cardinals[index % 16]
    }
}

// MARK: - Double 拡張

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
