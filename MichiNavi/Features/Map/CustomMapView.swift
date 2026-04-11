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
        if let img = combined {
            self.centerOffset = CGPoint(x: 0, y: img.size.height / 2 - Self.iconPointSize)
        } else {
            self.centerOffset = CGPoint(x: 0, y: -(Self.iconPointSize / 2))
        }
    }
}

// MARK: - Country Sign Annotation

final class CountrySignAnnotation: NSObject, MKAnnotation {
    let sign: CountrySign
    var isFavorite: Bool
    var isVisited: Bool

    var coordinate: CLLocationCoordinate2D { sign.coordinate }
    var title: String? { sign.name }
    var signId: String { sign.id }

    init(sign: CountrySign, isFavorite: Bool, isVisited: Bool) {
        self.sign = sign
        self.isFavorite = isFavorite
        self.isVisited = isVisited
    }
}

// MARK: - Country Sign Annotation View

final class CountrySignAnnotationView: MKAnnotationView {

    static let reuseID = "countrySign"

    private static let thumbnailSize: CGFloat = 40
    private static let labelFont = UIFont.systemFont(ofSize: 10, weight: .medium)
    private static let maxLabelWidth: CGFloat = 90
    private static let labelPaddingH: CGFloat = 4
    private static let labelPaddingV: CGFloat = 2
    private static let thumbnailLabelGap: CGFloat = 2

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        if let csa = annotation as? CountrySignAnnotation {
            updateImage(sign: csa.sign, isFavorite: csa.isFavorite, isVisited: csa.isVisited)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateImage(sign: CountrySign, isFavorite: Bool, isVisited: Bool, showLabel: Bool = true) {
        let thumbnail = Self.makeThumbnail(imageName: sign.imageName, isFavorite: isFavorite, isVisited: isVisited)
        let label = showLabel ? sign.name : ""
        self.image = Self.makeComposite(thumbnail: thumbnail, label: label)
        if let img = self.image {
            self.centerOffset = CGPoint(x: 0, y: -(img.size.height / 2 - Self.thumbnailSize / 2))
        }
    }

    /// カントリーサイン画像サムネイルを生成（画像がなければ SF Symbol で代用）
    private static func makeThumbnail(imageName: String?, isFavorite: Bool, isVisited: Bool) -> UIImage {
        let size = CGSize(width: thumbnailSize, height: thumbnailSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            // 角丸クリッピング
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
            path.addClip()

            // カントリーサイン画像 or プレースホルダー
            if let name = imageName,
               let filePath = Bundle.main.path(forResource: name, ofType: "jpg"),
               let csImage = UIImage(contentsOfFile: filePath) {
                // アスペクト比を保ってサムネイル内に収める（letterbox）
                let imgSize = csImage.size
                let scale = min(thumbnailSize / imgSize.width, thumbnailSize / imgSize.height)
                let fitW = imgSize.width * scale
                let fitH = imgSize.height * scale
                let fitRect = CGRect(
                    x: (thumbnailSize - fitW) / 2,
                    y: (thumbnailSize - fitH) / 2,
                    width: fitW,
                    height: fitH
                )
                UIColor.white.setFill()
                UIRectFill(rect)
                csImage.draw(in: fitRect)
            } else {
                // プレースホルダー背景
                UIColor.systemGray5.setFill()
                UIRectFill(rect)
                // SF Symbol
                let symConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
                if let sym = UIImage(systemName: "signpost.right", withConfiguration: symConfig) {
                    let symSize = sym.size
                    let x = (thumbnailSize - symSize.width) / 2
                    let y = (thumbnailSize - symSize.height) / 2
                    sym.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
                        .draw(at: CGPoint(x: x, y: y))
                }
            }

            // お気に入り / 踏破バッジ（右上）
            if isFavorite || isVisited {
                let badgeSymbol = isFavorite ? "heart.fill" : "checkmark.shield.fill"
                let badgeColor: UIColor = isFavorite ? .systemRed : .systemBlue
                let badgeConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                if let badge = UIImage(systemName: badgeSymbol, withConfiguration: badgeConfig) {
                    let bx = thumbnailSize - badge.size.width - 2
                    let by: CGFloat = 2
                    // バッジ背景（白丸）
                    let bgRect = CGRect(x: bx - 2, y: by - 2, width: badge.size.width + 4, height: badge.size.height + 4)
                    UIColor.white.setFill()
                    UIBezierPath(ovalIn: bgRect).fill()
                    // バッジ描画
                    badge.withTintColor(badgeColor, renderingMode: .alwaysOriginal)
                        .draw(at: CGPoint(x: bx, y: by))
                }
            }
        }
    }

    /// サムネイル + ラベルを縦に合成
    private static func makeComposite(thumbnail: UIImage, label: String) -> UIImage? {
        guard !label.isEmpty else { return thumbnail }

        let maxTextWidth = maxLabelWidth - labelPaddingH * 2
        let textSize = (label as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: labelFont.lineHeight * 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: labelFont],
            context: nil
        ).size

        let labelWidth = min(ceil(textSize.width) + labelPaddingH * 2, maxLabelWidth)
        let labelHeight = ceil(textSize.height) + labelPaddingV * 2
        let totalWidth = max(thumbnail.size.width, labelWidth)
        let totalHeight = thumbnail.size.height + thumbnailLabelGap + labelHeight

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight), format: format).image { _ in
            // サムネイルを中央上に描画
            let thumbX = (totalWidth - thumbnail.size.width) / 2
            thumbnail.draw(at: CGPoint(x: thumbX, y: 0))

            // ラベル背景
            let labelX = (totalWidth - labelWidth) / 2
            let labelY = thumbnail.size.height + thumbnailLabelGap
            let labelRect = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(roundedRect: labelRect, cornerRadius: 3).fill()

            // テキスト
            let textRect = CGRect(
                x: labelX + labelPaddingH,
                y: labelY + labelPaddingV,
                width: labelWidth - labelPaddingH * 2,
                height: labelHeight - labelPaddingV * 2
            )
            (label as NSString).draw(in: textRect, withAttributes: [
                .font: labelFont,
                .foregroundColor: UIColor.darkGray
            ])
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

    // カントリーサインアノテーション
    let countrySigns: [CountrySign]
    let favoriteSignIds: Set<String>
    let visitedSignIds: Set<String>

    // 市町村境界オーバーレイ（MKPolygon / MKMultiPolygon）
    let boundaryOverlays: [MKOverlay]
    let showBoundaries: Bool

    // 選択された道の駅（タップ時にセット）
    @Binding var selectedStation: RoadsideStation?

    // 選択されたカントリーサイン（タップ時にセット）
    @Binding var selectedSign: CountrySign?

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
        mapView.register(CountrySignAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: CountrySignAnnotationView.reuseID)

        context.coordinator.applyTileOverlay(to: mapView, tileType: tileType, googleAPIKey: googleAPIKey)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator

        // タイルタイプまたは API キーが変わったとき
        if coord.currentTileType != tileType || coord.currentGoogleAPIKey != googleAPIKey {
            coord.applyTileOverlay(to: mapView, tileType: tileType, googleAPIKey: googleAPIKey)
        }

        // 道の駅アノテーション更新
        coord.syncAnnotations(mapView: mapView,
                              stations: stations,
                              favoriteIds: favoriteIds,
                              visitedIds: visitedIds)

        // カントリーサインアノテーション更新
        coord.syncCountrySignAnnotations(mapView: mapView,
                                         signs: countrySigns,
                                         favoriteIds: favoriteSignIds,
                                         visitedIds: visitedSignIds)

        // 境界オーバーレイ: データが差し替わった場合のみリセット
        coord.resetBoundaryOverlaysIfNeeded(mapView: mapView, show: showBoundaries)

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

        /// 現在マップに追加している境界の市町村コードセット（追加済みの追跡用）
        private var municipalityCodesOnMap = Set<String>()

        /// 画面短辺 150 km 以上でラベルを非表示にする閾値（度）
        private let labelHideThreshold = 150.0 * 0.009
        private var showLabels = true

        /// 境界ラインは ~80 km 以下で表示
        private let boundaryShowThreshold = 80.0 * 0.009
        private var showBoundaryOverlays = false

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

        // MARK: Boundary overlay management

        /// showBoundaries が false になった場合に全境界を除去するリセット処理
        func resetBoundaryOverlaysIfNeeded(mapView: MKMapView, show: Bool) {
            guard !show, !municipalityCodesOnMap.isEmpty else { return }
            removeBoundaryOverlays(from: mapView)
        }

        /// 表示領域内の境界のみをマップに追加・削除（差分更新）
        private func updateVisibleBoundaryOverlays(in mapView: MKMapView) {
            guard showBoundaryOverlays && parent.showBoundaries else {
                if !municipalityCodesOnMap.isEmpty { removeBoundaryOverlays(from: mapView) }
                return
            }

            let allOverlays = parent.boundaryOverlays
            guard !allOverlays.isEmpty else { return }

            // 表示領域を50%拡大してバッファとする
            let visible = mapView.visibleMapRect
            let padded = MKMapRect(
                x: visible.minX - visible.width * 0.5,
                y: visible.minY - visible.height * 0.5,
                width: visible.width * 2,
                height: visible.height * 2
            )

            // 表示領域と交差する市町村コードを集計
            var visibleCodes = Set<String>()
            for overlay in allOverlays {
                guard padded.intersects(overlay.boundingMapRect) else { continue }
                if let code = (overlay as? MKShape)?.title, !code.isEmpty {
                    visibleCodes.insert(code)
                }
            }

            // マップから除去すべき境界
            let codesToRemove = municipalityCodesOnMap.subtracting(visibleCodes)
            if !codesToRemove.isEmpty {
                let toRemove = mapView.overlays.filter { overlay in
                    guard overlay is MKPolygon || overlay is MKMultiPolygon else { return false }
                    return codesToRemove.contains((overlay as? MKShape)?.title ?? "")
                }
                mapView.removeOverlays(toRemove)
                codesToRemove.forEach { municipalityCodesOnMap.remove($0) }
            }

            // マップへ追加すべき境界
            let codesToAdd = visibleCodes.subtracting(municipalityCodesOnMap)
            if !codesToAdd.isEmpty {
                let toAdd = allOverlays.filter { overlay in
                    codesToAdd.contains((overlay as? MKShape)?.title ?? "")
                }
                mapView.addOverlays(toAdd, level: .aboveRoads)
                codesToAdd.forEach { municipalityCodesOnMap.insert($0) }
            }
        }

        private func removeBoundaryOverlays(from mapView: MKMapView) {
            let toRemove = mapView.overlays.filter { $0 is MKPolygon || $0 is MKMultiPolygon }
            mapView.removeOverlays(toRemove)
            municipalityCodesOnMap.removeAll()
        }

        // MARK: Annotation sync – 道の駅

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

        // MARK: Annotation sync – カントリーサイン

        func syncCountrySignAnnotations(mapView: MKMapView,
                                         signs: [CountrySign],
                                         favoriteIds: Set<String>,
                                         visitedIds: Set<String>) {
            let existing = mapView.annotations.compactMap { $0 as? CountrySignAnnotation }
            let newIdSet = Set(signs.map { $0.id })

            let toRemove = existing.filter { !newIdSet.contains($0.signId) }
            if !toRemove.isEmpty { mapView.removeAnnotations(toRemove) }

            let existingMap = Dictionary(existing.map { ($0.signId, $0) },
                                         uniquingKeysWith: { $1 })

            for sign in signs {
                let isFav = favoriteIds.contains(sign.id)
                let isVis = visitedIds.contains(sign.id)

                if let ann = existingMap[sign.id] {
                    if ann.isFavorite != isFav || ann.isVisited != isVis {
                        ann.isFavorite = isFav
                        ann.isVisited = isVis
                        if let view = mapView.view(for: ann) as? CountrySignAnnotationView {
                            view.updateImage(sign: ann.sign, isFavorite: isFav, isVisited: isVis, showLabel: showLabels)
                        }
                    }
                } else {
                    mapView.addAnnotation(
                        CountrySignAnnotation(sign: sign, isFavorite: isFav, isVisited: isVis)
                    )
                }
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let multi = overlay as? MKMultiPolygon {
                let renderer = MKMultiPolygonRenderer(multiPolygon: multi)
                renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.55)
                renderer.lineWidth = 1.2
                renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.03)
                return renderer
            }
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.55)
                renderer.lineWidth = 1.2
                renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.03)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let sa = annotation as? StationAnnotation {
                let view = (mapView.dequeueReusableAnnotationView(
                    withIdentifier: StationAnnotationView.reuseID) as? StationAnnotationView)
                    ?? StationAnnotationView(annotation: sa, reuseIdentifier: StationAnnotationView.reuseID)
                view.annotation = sa
                view.updateImage(isFavorite: sa.isFavorite, isVisited: sa.isVisited, showLabel: showLabels)
                return view
            }

            if let csa = annotation as? CountrySignAnnotation {
                let view = (mapView.dequeueReusableAnnotationView(
                    withIdentifier: CountrySignAnnotationView.reuseID) as? CountrySignAnnotationView)
                    ?? CountrySignAnnotationView(annotation: csa, reuseIdentifier: CountrySignAnnotationView.reuseID)
                view.annotation = csa
                view.updateImage(sign: csa.sign, isFavorite: csa.isFavorite, isVisited: csa.isVisited, showLabel: showLabels)
                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let sa = view.annotation as? StationAnnotation {
                mapView.deselectAnnotation(view.annotation, animated: false)
                parent.selectedStation = sa.station
            } else if let csa = view.annotation as? CountrySignAnnotation {
                mapView.deselectAnnotation(view.annotation, animated: false)
                parent.selectedSign = csa.sign
            }
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.onCameraChange(mapView.region)

            let shortSide = min(mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta)

            // 道の駅ラベル表示切り替え
            let newShowLabels = shortSide < labelHideThreshold
            if newShowLabels != showLabels {
                showLabels = newShowLabels
                refreshLabelVisibility(mapView)
            }

            // 境界ライン表示切り替え＋表示領域フィルタリング
            let newShowBoundaries = shortSide < boundaryShowThreshold
            if newShowBoundaries != showBoundaryOverlays {
                showBoundaryOverlays = newShowBoundaries
                if !newShowBoundaries {
                    removeBoundaryOverlays(from: mapView)
                    return
                }
            }
            // 表示中の場合はパンのたびに表示領域を更新
            if showBoundaryOverlays {
                updateVisibleBoundaryOverlays(in: mapView)
            }
        }

        private func refreshLabelVisibility(_ mapView: MKMapView) {
            for annotation in mapView.annotations {
                if let ann = annotation as? StationAnnotation,
                   let view = mapView.view(for: ann) as? StationAnnotationView {
                    view.updateImage(isFavorite: ann.isFavorite, isVisited: ann.isVisited, showLabel: showLabels)
                }
                if let csa = annotation as? CountrySignAnnotation,
                   let view = mapView.view(for: csa) as? CountrySignAnnotationView {
                    view.updateImage(sign: csa.sign, isFavorite: csa.isFavorite, isVisited: csa.isVisited, showLabel: showLabels)
                }
            }
        }
    }
}
