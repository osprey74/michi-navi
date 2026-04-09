import SwiftUI
import MapKit
import CoreLocation

/// OS共有シートで位置情報を共有するラッパー
///
/// `MKMapItem`（com.apple.mapkit.map-item）と Apple Maps URL（public.url）の両方を渡すことで、
/// NaviTimeなどURL共有拡張を持つナビアプリも含めた幅広いアプリを共有先に表示する。
struct LocationShareSheet: UIViewControllerRepresentable {

    let coordinate: CLLocationCoordinate2D
    let name: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = []

        // MKMapItem: MapKit対応アプリ向け
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        items.append(mapItem)

        // Apple Maps URL: NaviTimeなどURL共有拡張を持つアプリ向け
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(encoded)"
        if let url = URL(string: urlString) {
            items.append(url)
        }

        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
