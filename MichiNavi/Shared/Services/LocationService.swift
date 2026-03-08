import Foundation
import CoreLocation

/// CoreLocation をラップし、走行中の位置情報・速度・方位を提供するサービス
///
/// - Important: Info.plist に以下のキーが必要です
///   - NSLocationAlwaysAndWhenInUseUsageDescription
///   - UIBackgroundModes: [location]
@Observable
final class LocationService: NSObject {

    // MARK: - Published 状態
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var speedKmh: Double = 0
    var heading: Double = 0

    // MARK: - Private
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5          // 5m ごとに更新
        manager.headingFilter = 5           // 5° ごとに更新
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .automotiveNavigation
    }

    // MARK: - Public Interface

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways ||
           authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        // 速度（m/s → km/h）、負値は停車中
        let rawSpeed = location.speed
        speedKmh = rawSpeed > 0 ? rawSpeed * 3.6 : 0
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // TODO: エラーハンドリング（ユーザーへの通知）
        print("LocationService error: \(error.localizedDescription)")
    }
}
