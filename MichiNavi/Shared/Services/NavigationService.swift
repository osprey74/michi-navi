import Foundation
import MapKit
import UIKit

// MARK: - NavigationApp

/// 対応ナビアプリ
enum NavigationApp: String, CaseIterable, Identifiable {
    case appleMaps  = "Apple Maps"
    case googleMaps = "Google Maps"
    case yahooCar   = "Yahoo!カーナビ"  // yjcarnavi://
    case waze       = "Waze"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .appleMaps:  return "map.fill"
        case .googleMaps: return "globe"
        case .yahooCar:   return "car.fill"
        case .waze:       return "waveform.path.ecg"
        }
    }

    /// アプリの起動確認に使う URL スキーム（nil = Apple Maps = 常に利用可）
    var urlScheme: String? {
        switch self {
        case .appleMaps:  return nil
        case .googleMaps: return "comgooglemaps://"
        case .yahooCar:   return "yjcarnavi://"
        case .waze:       return "waze://"
        }
    }

    /// 目的地への URL を生成する（Apple Maps は nil を返し MKMapItem で処理）
    func makeURL(latitude: Double, longitude: Double, name: String) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        switch self {
        case .appleMaps:
            return nil
        case .googleMaps:
            return URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving")
        case .yahooCar:
            return URL(string: "yjcarnavi://navi/select?lat=\(latitude)&lon=\(longitude)&name=\(encoded)")
        case .waze:
            return URL(string: "waze://?ll=\(latitude),\(longitude)&navigate=yes")
        }
    }
}

// MARK: - NavigationService

/// ナビゲーション連携サービス
@Observable
final class NavigationService {

    /// 現在のナビ目的地
    private(set) var destination: RoadsideStation?

    // MARK: - アプリ検出

    /// インストール済みナビアプリの一覧（Apple Maps は常に含む）
    func availableApps() -> [NavigationApp] {
        NavigationApp.allCases.filter { app in
            guard let scheme = app.urlScheme,
                  let url = URL(string: scheme) else {
                return true  // Apple Maps は常に利用可
            }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    // MARK: - ナビゲーション開始

    /// 指定アプリでナビゲーションを開始する
    func navigate(to station: RoadsideStation, with app: NavigationApp) {
        destination = station
        if app == .appleMaps {
            let placemark = MKPlacemark(coordinate: station.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = station.name
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
            return
        }
        if let url = app.makeURL(latitude: station.coordinate.latitude,
                                 longitude: station.coordinate.longitude,
                                 name: station.name) {
            UIApplication.shared.open(url)
        }
    }

    /// Apple Maps でナビゲーション（後方互換）
    func navigateInAppleMaps(to station: RoadsideStation) {
        navigate(to: station, with: .appleMaps)
    }

    func navigateInAppleMaps(to mapItem: MKMapItem) {
        destination = nil
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// 目的地をクリアする
    func clearDestination() {
        destination = nil
    }
}
