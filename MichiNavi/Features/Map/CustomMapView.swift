import SwiftUI
import MapKit
import CoreLocation

// MARK: - Station Annotation

final class StationAnnotation: NSObject, MKAnnotation {
    let station: RoadsideStation
    var isFavorite: Bool
    var isVisited: Bool

    var coordinate: CLLocationCoordinate2D { station.coordinate }
    var title: String? { station.name }
    var stationId: String { station.id }

    init(station: RoadsideStation, isFavorite: Bool, isVisited: Bool) {
        self.station = station
        self.isFavorite = isFavorite
        self.isVisited = isVisited
    }
}

// MARK: - Station Annotation View

final class StationAnnotationView: MKAnnotationView {

    static let reuseID = "station"

    private static let iconPointSize: CGFloat = 24
    private static let labelFont = UIFont.systemFont(ofSize: 11, weight: .medium)
    private static let maxLabelWidth: CGFloat = 100
    private static let labelPaddingH: CGFloat = 5
    private static let labelPaddingV: CGFloat = 2
    private static let iconLabelGap: CGFloat = 2

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        if let sa = annotation as? StationAnnotation {
            updateImage(isFavorite: sa.isFavorite, isVisited: sa.isVisited)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// SF Symbol をビットマップに色を焼き付けた UIImage に変換する
    private static func makeColoredIcon(symbolName: String, color: UIColor, pointSize: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: config) else { return nil }

        let imageView = UIImageView()
        imageView.frame = CGRect(origin: .zero, size: symbol.size)
        imageView.image = symbol.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = color
        imageView.backgroundColor = .clear

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: symbol.size, format: format)
        let result = renderer.image { _ in
            imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        }
        return result.withRenderingMode(.alwaysOriginal)
    }

    /// アイコン + 道の駅名ラベルを合成した UIImage を生成する（name が空の場合はアイコンのみ）
    private static func makeAnnotationImage(symbolName: String, color: UIColor, name: String) -> UIImage? {
        guard let iconImage = makeColoredIcon(symbolName: symbolName, color: color, pointSize: iconPointSize) else { return nil }

        // ラベルなしの場合はアイコンのみ返す
        guard !name.isEmpty else { return iconImage }

        // ラベルテキストのサイズを計算（最大 2 行）
        let maxTextWidth = maxLabelWidth - labelPaddingH * 2
        let maxTextHeight = labelFont.lineHeight * 2 + 2
        let textSize = (name as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: maxTextHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: labelFont],
            context: nil
        ).size

        let labelWidth = min(ceil(textSize.width) + labelPaddingH * 2, maxLabelWidth)
        let labelHeight = ceil(textSize.height) + labelPaddingV * 2
        let totalWidth = max(iconImage.size.width, labelWidth)
        let totalHeight = iconImage.size.height + iconLabelGap + labelHeight

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight), format: format).image { _ in
            // アイコンを水平中央に描画
            let iconX = (totalWidth - iconImage.size.width) / 2
            iconImage.draw(at: CGPoint(x: iconX, y: 0))

            // ラベル背景を描画
            let labelX = (totalWidth - labelWidth) / 2
            let labelY = iconImage.size.height + iconLabelGap
            let labelRect = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(roundedRect: labelRect, cornerRadius: 3).fill()

            // テキストを描画
            let textRect = CGRect(
                x: labelX + labelPaddingH,
                y: labelY + labelPaddingV,
                width: labelWidth - labelPaddingH * 2,
                height: labelHeight - labelPaddingV * 2
            )
            (name as NSString).draw(in: textRect, withAttributes: [
                .font: labelFont,
                .foregroundColor: UIColor.darkGray
            ])
        }
    }

    func updateImage(isFavorite: Bool, isVisited: Bool, showLabel: Bool = true) {
        let name = showLabel ? (annotation as? StationAnnotation)?.station.name ?? "" : ""

        let symbolName: String
        let color: UIColor
        switch (isFavorite, isVisited) {
        case (true, true):
            symbolName = "checkmark.shield.fill"
            color = .systemRed
        case (true, false):
            symbolName = "heart.fill"
            color = .systemRed
        case (false, true):
            symbolName = "checkmark.shield.fill"
            color = .systemBlue
        case (false, false):
            symbolName = "mappin.circle.fill"
            color = .systemOrange
        }

        let combined = Self.makeAnnotationImage(symbolName: symbolName, color: color, name: name)
        self.image = combined
        // アイコン底辺が地図座標に対応するようにオフセット計算
        // centerOffset.y = totalImageHeight/2 - iconPointSize
        if let img = combined {
            self.centerOffset = CGPoint(x: 0, y: img.size.height / 2 - Self.iconPointSize)
        } else {
            self.centerOffset = CGPoint(x: 0, y: -(Self.iconPointSize / 2))
        }
    }
}

// MARK: - CustomMapView

/// 国土地理院・OpenFreeMap・Google Maps などカスタムタイルに対応した MKMapView ラッパー
struct CustomMapView: UIViewRepresentable {

    // タイル設定
    let tileType: MapTileType
    let googleAPIKey: String

    // 道の駅アノテーション
    let stations: [RoadsideStation]
    let favoriteIds: Set<String>
    let visitedIds: Set<String>

    // 選択された道の駅（タップ時にセット）
    @Binding var selectedStation: RoadsideStation?

    // コマンド: セットすると地図がそのリージョンにアニメーション移動し、自動的に nil に戻る
    @Binding var commandedRegion: MKCoordinateRegion?

    // カメラ変更コールバック（表示領域が変わるたびに呼ばれる）
    let onCameraChange: (MKCoordinateRegion) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.backgroundColor = .systemGray6
        mapView.register(StationAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: StationAnnotationView.reuseID)

        context.coordinator.applyTileOverlay(to: mapView, tileType: tileType, googleAPIKey: googleAPIKey)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator

        // タイルタイプまたは API キーが変わったとき
        if coord.currentTileType != tileType || coord.currentGoogleAPIKey != googleAPIKey {
            coord.applyTileOverlay(to: mapView, tileType: tileType, googleAPIKey: googleAPIKey)
        }

        // アノテーション更新
        coord.syncAnnotations(mapView: mapView,
                              stations: stations,
                              favoriteIds: favoriteIds,
                              visitedIds: visitedIds)

        // コマンドによるリージョン移動
        if let region = commandedRegion {
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async { commandedRegion = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
}

// MARK: - Coordinator

extension CustomMapView {

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {

        var parent: CustomMapView
        var currentTileType: MapTileType?
        var currentGoogleAPIKey: String = ""
        private var currentTileOverlay: MKTileOverlay?

        /// 画面短辺 150 km 以上でラベルを非表示にする閾値（度）
        private let labelHideThreshold = 150.0 * 0.009
        private var showLabels = true

        init(parent: CustomMapView) { self.parent = parent }

        // MARK: Tile overlay

        func applyTileOverlay(to mapView: MKMapView, tileType: MapTileType, googleAPIKey: String) {
            // 既存のカスタムオーバーレイを除去
            if let existing = currentTileOverlay {
                mapView.removeOverlay(existing)
                currentTileOverlay = nil
            }

            // Apple Maps: ネイティブ MKMapView をそのまま使用（オーバーレイ不要）
            if tileType.isAppleMaps {
                mapView.mapType = .standard
                currentTileType = tileType
                currentGoogleAPIKey = googleAPIKey
                return
            }

            // Google Maps: API キーがなければスキップ
            if tileType.isGoogleMaps && googleAPIKey.isEmpty {
                currentTileType = tileType
                currentGoogleAPIKey = googleAPIKey
                return
            }

            let overlay: MKTileOverlay
            if tileType.isGoogleMaps {
                overlay = GoogleMapsTileOverlay(apiKey: googleAPIKey)
            } else {
                // 国土地理院など: カスタムタイルオーバーレイ
                overlay = MKTileOverlay(urlTemplate: tileType.tileURLTemplate)
                overlay.canReplaceMapContent = true
                overlay.tileSize = CGSize(width: 256, height: 256)
            }

            mapView.addOverlay(overlay, level: .aboveRoads)
            currentTileOverlay = overlay
            currentTileType = tileType
            currentGoogleAPIKey = googleAPIKey
        }

        // MARK: Annotation sync

        func syncAnnotations(mapView: MKMapView,
                             stations: [RoadsideStation],
                             favoriteIds: Set<String>,
                             visitedIds: Set<String>) {
            let existing = mapView.annotations.compactMap { $0 as? StationAnnotation }
            let newIdSet = Set(stations.map { $0.id })

            // 不要なアノテーションを削除
            let toRemove = existing.filter { !newIdSet.contains($0.stationId) }
            if !toRemove.isEmpty { mapView.removeAnnotations(toRemove) }

            let existingMap = Dictionary(existing.map { ($0.stationId, $0) },
                                         uniquingKeysWith: { $1 })

            for station in stations {
                let isFav = favoriteIds.contains(station.id)
                let isVis = visitedIds.contains(station.id)

                if let ann = existingMap[station.id] {
                    // ステータスが変わったときだけビューを更新
                    if ann.isFavorite != isFav || ann.isVisited != isVis {
                        ann.isFavorite = isFav
                        ann.isVisited = isVis
                        if let view = mapView.view(for: ann) as? StationAnnotationView {
                            view.updateImage(isFavorite: isFav, isVisited: isVis, showLabel: showLabels)
                        }
                    }
                } else {
                    // 新規追加
                    mapView.addAnnotation(
                        StationAnnotation(station: station, isFavorite: isFav, isVisited: isVis)
                    )
                }
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let sa = annotation as? StationAnnotation else { return nil }

            let view = (mapView.dequeueReusableAnnotationView(
                withIdentifier: StationAnnotationView.reuseID) as? StationAnnotationView)
                ?? StationAnnotationView(annotation: sa, reuseIdentifier: StationAnnotationView.reuseID)

            view.annotation = sa
            view.updateImage(isFavorite: sa.isFavorite, isVisited: sa.isVisited, showLabel: showLabels)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let sa = view.annotation as? StationAnnotation else { return }
            mapView.deselectAnnotation(view.annotation, animated: false)
            parent.selectedStation = sa.station
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.onCameraChange(mapView.region)

            // 画面短辺が 150 km を超えたらラベルを非表示に切り替える
            let shortSide = min(mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta)
            let newShowLabels = shortSide < labelHideThreshold
            if newShowLabels != showLabels {
                showLabels = newShowLabels
                refreshLabelVisibility(mapView)
            }
        }

        private func refreshLabelVisibility(_ mapView: MKMapView) {
            for annotation in mapView.annotations {
                guard let ann = annotation as? StationAnnotation,
                      let view = mapView.view(for: ann) as? StationAnnotationView else { continue }
                view.updateImage(isFavorite: ann.isFavorite, isVisited: ann.isVisited, showLabel: showLabels)
            }
        }
    }
}
