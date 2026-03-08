import Foundation
import CoreLocation

/// 現在の走行状態を表すモデル
/// App Group を通じて全ターゲット（CarPlay Extension / Widget / Live Activity）と共有する
@Observable
final class DriveState {

    // MARK: - 位置・速度
    var currentLocation: CLLocationCoordinate2D?
    var speedKmh: Double = 0
    var heading: Double = 0

    // MARK: - ルート
    var destinationName: String?
    var remainingDistanceMeters: Double?
    var estimatedArrivalTime: Date?

    // MARK: - 気象
    var weatherDescription: String = "取得中..."
    var temperatureCelsius: Double?
    var weatherSymbolName: String = "cloud"

    // MARK: - LocationService 同期
    private var syncTimer: Timer?
    private weak var stationService: RoadsideStationService?
    private var stationUpdateCounter = 9  // 初回は1秒後に検索開始

    func bind(to service: LocationService, stationService: RoadsideStationService? = nil) {
        self.stationService = stationService
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak service] _ in
            guard let self, let service else { return }
            self.speedKmh = service.speedKmh
            self.heading = service.heading
            self.currentLocation = service.currentLocation?.coordinate

            // 道の駅検索は 5秒間隔（Timer 0.5s × 10回 = 5秒）
            self.stationUpdateCounter += 1
            if self.stationUpdateCounter >= 10 {
                self.stationUpdateCounter = 0
                if let loc = self.currentLocation {
                    self.stationService?.updateNearbyStations(
                        location: loc,
                        heading: self.heading,
                        speedKmh: self.speedKmh
                    )
                }
            }
        }
    }

    func unbind() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

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
