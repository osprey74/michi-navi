import Foundation
import MapKit

/// Apple Maps 連携ナビゲーションサービス
@Observable
final class NavigationService {

    /// 現在のナビ目的地
    private(set) var destination: RoadsideStation?

    /// Apple Maps を起動してナビゲーションを開始する
    func navigateInAppleMaps(to station: RoadsideStation) {
        destination = station

        let placemark = MKPlacemark(coordinate: station.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = station.name

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// MKMapItem を使って Apple Maps ナビゲーションを開始する
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
