import Foundation
import CoreLocation

/// 現在の走行状態を表すモデル
/// App Group を通じて全ターゲット（CarPlay Extension / Widget / Live Activity）と共有する
@Observable
final class DriveState {

    // MARK: - 位置・速度
    var currentLocation: CLLocationCoordinate2D?
    var speedKmh: Double = 0
    var heading: Double = 0          // 方位角（度）

    // MARK: - ルート
    var destinationName: String?
    var remainingDistanceMeters: Double?
    var estimatedArrivalTime: Date?

    // MARK: - 気象åå
    var weatherDescription: String = "取得中..."
    var temperatureCelsius: Double?
    var weatherSymbolName: String = "cloud"

    // MARK: - 計算プロパティ
    var speedText: String {
        guard speedKmh > 0 else { return "-- km/h" }
        return String(format: "%.0f km/h", speedKmh)
    }

    var remainingDistanceText: String {
        guard let dist = remainingDistanceMeters else { return "--" }
        if dist >= 1000 {
            return String(format: "%.1f km", dist / 1000)
        } else {
            return String(format: "%.0f m", dist)
        }
    }

    var arrivalTimeText: String {
        guard let eta = estimatedArrivalTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: eta)
    }

    var temperatureText: String {
        guard let temp = temperatureCelsius else { return "--°C" }
        return String(format: "%.1f°C", temp)
    }
}
