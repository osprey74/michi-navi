import CarPlay
import MapKit

/// CarPlay 画面のライフサイクルを管理するデリゲート
///
/// - Important: Driving Task カテゴリではテンプレート階層は最大 2 段まで。
///   走行中のテキスト入力や過度な情報表示は Apple 審査で却下される。
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var poiTemplate: CPPointOfInterestTemplate?
    private var driveInfoTemplate: CPInformationTemplate?
    private var stationListTemplate: CPListTemplate?
    private var updateTimer: Timer?

    /// AppDelegate が保持する共有状態を取得
    private var driveState: DriveState? {
        AppDelegate.shared?.driveState
    }

    private var stationService: RoadsideStationService? {
        AppDelegate.shared?.stationService
    }

    private var navigationService: NavigationService? {
        AppDelegate.shared?.navigationService
    }

    private var appSettings: AppSettings? {
        AppDelegate.shared?.appSettings
    }

    // MARK: - アイコンヘルパー

    /// SF Symbol をビットマップに色を焼き付けた UIImage を返す
    private static func makeColoredIcon(symbolName: String, color: UIColor, pointSize: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: config) else { return nil }
        let iv = UIImageView(frame: CGRect(origin: .zero, size: symbol.size))
        iv.image = symbol.withRenderingMode(.alwaysTemplate)
        iv.tintColor = color
        iv.backgroundColor = .clear
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = UIScreen.main.scale
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: symbol.size, format: fmt).image { _ in
            iv.layer.render(in: UIGraphicsGetCurrentContext()!)
        }.withRenderingMode(.alwaysOriginal)
    }

    /// お気に入り・到達状態に合わせたアイコンを返す（iPhone マーカーと同一配色）
    private func stationIcon(isFavorite: Bool, isVisited: Bool, size: CGFloat) -> UIImage? {
        switch (isFavorite, isVisited) {
        case (true, true):   return Self.makeColoredIcon(symbolName: "checkmark.shield.fill", color: .systemRed,    pointSize: size)
        case (true, false):  return Self.makeColoredIcon(symbolName: "heart.fill",             color: .systemRed,    pointSize: size)
        case (false, true):  return Self.makeColoredIcon(symbolName: "checkmark.shield.fill", color: .systemBlue,   pointSize: size)
        case (false, false): return Self.makeColoredIcon(symbolName: "mappin.circle.fill",     color: .systemOrange, pointSize: size)
        }
    }

    // MARK: - Scene Lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupRootTemplate()
        startAutoUpdates()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        stopAutoUpdates()
        self.interfaceController = nil
    }

    // MARK: - Root Template（CPPointOfInterestTemplate）

    private func setupRootTemplate() {
        let template = buildPOITemplate()
        self.poiTemplate = template
        interfaceController?.setRootTemplate(template, animated: false, completion: nil)
    }

    private func buildPOITemplate() -> CPPointOfInterestTemplate {
        let pois = buildPOIList()

        let template = CPPointOfInterestTemplate(
            title: "道の駅",
            pointsOfInterest: pois,
            selectedIndex: NSNotFound
        )
        template.pointOfInterestDelegate = self

        // 左バーボタン: 道の駅リスト
        let listButton = CPBarButton(image: UIImage(systemName: "list.bullet") ?? UIImage()) { [weak self] _ in
            self?.showStationList()
        }

        // 右バーボタン: ドライブ情報
        let infoButton = CPBarButton(image: UIImage(systemName: "info.circle") ?? UIImage()) { [weak self] _ in
            self?.showDriveInfo()
        }

        template.leadingNavigationBarButtons = [listButton]
        template.trailingNavigationBarButtons = [infoButton]

        return template
    }

    /// 近くの道の駅から CPPointOfInterest 配列を生成（最大12件）
    private func buildPOIList() -> [CPPointOfInterest] {
        guard let service = stationService else { return [] }
        let favIds = appSettings?.favoriteStationIds ?? []
        let visIds = appSettings?.visitedStationIds ?? []

        return service.nearbyStations.prefix(12).map { nearby in
            let isFav = favIds.contains(nearby.station.id)
            let isVis = visIds.contains(nearby.station.id)

            let placemark = MKPlacemark(coordinate: nearby.station.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = nearby.station.name

            let poi = CPPointOfInterest(
                location: mapItem,
                title: nearby.station.name,
                subtitle: "\(nearby.distanceText) · \(nearby.cardinalDirection)",
                summary: nearby.station.roadName,
                detailTitle: nearby.station.name,
                detailSubtitle: "\(nearby.distanceText) · \(nearby.cardinalDirection)",
                detailSummary: [
                    nearby.station.roadName,
                    nearby.station.prefecture,
                    nearby.station.municipality
                ].compactMap { $0 }.joined(separator: " · "),
                pinImage: stationIcon(isFavorite: isFav, isVisited: isVis, size: 24)
            )

            // ナビ開始ボタン
            let navButton = CPTextButton(title: "ナビ開始", textStyle: .confirm) { [weak self] _ in
                self?.navigationService?.navigateInAppleMaps(to: nearby.station)
            }
            poi.primaryButton = navButton

            // 道の駅IDを userInfo に保存
            poi.userInfo = nearby.station.id

            return poi
        }
    }

    // MARK: - 道の駅リスト（CPListTemplate）— 駐車中のみ表示

    private func showStationList() {
        // 走行中はリスト表示を制限
        let speed = driveState?.speedKmh ?? 0
        if speed > 5 {
            let alert = CPAlertTemplate(
                titleVariants: ["駐車中に利用できます"],
                actions: [
                    CPAlertAction(title: "OK", style: .cancel, handler: { [weak self] _ in
                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    })
                ]
            )
            interfaceController?.presentTemplate(alert, animated: true, completion: nil)
            return
        }

        let template = buildStationListTemplate()
        self.stationListTemplate = template
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func buildStationListTemplate() -> CPListTemplate {
        guard let service = stationService, let state = driveState else {
            let emptyItem = CPListItem(text: "データなし", detailText: nil)
            let section = CPListSection(items: [emptyItem])
            return CPListTemplate(title: "道の駅", sections: [section])
        }

        let favIds = appSettings?.favoriteStationIds ?? []
        let visIds = appSettings?.visitedStationIds ?? []

        // 速度表示
        let speedItem = CPListItem(
            text: state.speedText,
            detailText: "現在速度",
            image: UIImage(systemName: "speedometer")
        )
        let speedSection = CPListSection(items: [speedItem], header: "走行情報", sectionIndexTitle: nil)

        // 前方の道の駅
        let nearbyItems: [CPListItem]
        let stations = service.nearbyStations
        if stations.isEmpty {
            nearbyItems = [CPListItem(text: "前方に道の駅なし", detailText: "走行中に自動更新されます")]
        } else {
            nearbyItems = stations.prefix(10).map { nearby -> CPListItem in
                let isFav = favIds.contains(nearby.station.id)
                let isVis = visIds.contains(nearby.station.id)
                let item = CPListItem(
                    text: nearby.station.name,
                    detailText: "\(nearby.distanceText) · \(nearby.cardinalDirection) · \(nearby.station.roadName ?? "")",
                    image: stationIcon(isFavorite: isFav, isVisited: isVis, size: 20)
                )
                item.handler = { [weak self] _, completion in
                    self?.navigationService?.navigateInAppleMaps(to: nearby.station)
                    completion()
                }
                return item
            }
        }
        let nearbySection = CPListSection(items: nearbyItems, header: "前方の道の駅", sectionIndexTitle: nil)

        // お気に入りセクション（登録済みのみ表示）
        var sections: [CPListSection] = [speedSection, nearbySection]
        let favStations = service.allStations.filter { favIds.contains($0.id) }
        if !favStations.isEmpty {
            let favItems = favStations.prefix(10).map { station -> CPListItem in
                let isVis = visIds.contains(station.id)
                let item = CPListItem(
                    text: station.name,
                    detailText: station.roadName ?? "",
                    image: stationIcon(isFavorite: true, isVisited: isVis, size: 20)
                )
                item.handler = { [weak self] _, completion in
                    self?.navigationService?.navigateInAppleMaps(to: station)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: favItems, header: "お気に入り", sectionIndexTitle: nil))
        }

        return CPListTemplate(title: "道の駅", sections: sections)
    }

    // MARK: - ドライブ情報

    private func showDriveInfo() {
        let template = buildDriveInfoTemplate()
        self.driveInfoTemplate = template
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func buildDriveInfoTemplate() -> CPInformationTemplate {
        let state = driveState
        let items = [
            CPInformationItem(title: "現在速度", detail: state?.speedText ?? "-- km/h"),
            CPInformationItem(title: "天気", detail: state?.weatherDescription ?? "取得中..."),
            CPInformationItem(title: "気温", detail: state?.temperatureText ?? "--°C"),
        ]
        return CPInformationTemplate(
            title: "ドライブ情報",
            layout: .leading,
            items: items,
            actions: []
        )
    }

    // MARK: - 自動更新

    private func startAutoUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshAllTemplates()
        }
    }

    private func stopAutoUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refreshAllTemplates() {
        // POI テンプレート更新
        if let template = poiTemplate {
            let pois = buildPOIList()
            template.setPointsOfInterest(pois, selectedIndex: NSNotFound)
        }

        // ドライブ情報更新
        if let state = driveState, let template = driveInfoTemplate {
            template.items = [
                CPInformationItem(title: "現在速度", detail: state.speedText),
                CPInformationItem(title: "天気", detail: state.weatherDescription),
                CPInformationItem(title: "気温", detail: state.temperatureText),
            ]
        }

        // リスト更新
        refreshStationListTemplate()
    }

    private func refreshStationListTemplate() {
        guard let template = stationListTemplate,
              let service = stationService,
              let state = driveState else { return }

        let favIds = appSettings?.favoriteStationIds ?? []
        let visIds = appSettings?.visitedStationIds ?? []

        let speedItem = CPListItem(
            text: state.speedText,
            detailText: "現在速度",
            image: UIImage(systemName: "speedometer")
        )
        let speedSection = CPListSection(items: [speedItem], header: "走行情報", sectionIndexTitle: nil)

        let nearbyItems: [CPListItem]
        let stations = service.nearbyStations
        if stations.isEmpty {
            nearbyItems = [CPListItem(text: "前方に道の駅なし", detailText: "走行中に自動更新されます")]
        } else {
            nearbyItems = stations.prefix(10).map { nearby -> CPListItem in
                let isFav = favIds.contains(nearby.station.id)
                let isVis = visIds.contains(nearby.station.id)
                let item = CPListItem(
                    text: nearby.station.name,
                    detailText: "\(nearby.distanceText) · \(nearby.cardinalDirection) · \(nearby.station.roadName ?? "")",
                    image: stationIcon(isFavorite: isFav, isVisited: isVis, size: 20)
                )
                item.handler = { [weak self] _, completion in
                    self?.navigationService?.navigateInAppleMaps(to: nearby.station)
                    completion()
                }
                return item
            }
        }
        let nearbySection = CPListSection(items: nearbyItems, header: "前方の道の駅", sectionIndexTitle: nil)

        var sections: [CPListSection] = [speedSection, nearbySection]
        let favStations = service.allStations.filter { favIds.contains($0.id) }
        if !favStations.isEmpty {
            let favItems = favStations.prefix(10).map { station -> CPListItem in
                let isVis = visIds.contains(station.id)
                let item = CPListItem(
                    text: station.name,
                    detailText: station.roadName ?? "",
                    image: stationIcon(isFavorite: true, isVisited: isVis, size: 20)
                )
                item.handler = { [weak self] _, completion in
                    self?.navigationService?.navigateInAppleMaps(to: station)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: favItems, header: "お気に入り", sectionIndexTitle: nil))
        }

        template.updateSections(sections)
    }
}

// MARK: - CPPointOfInterestTemplateDelegate

extension CarPlaySceneDelegate: CPPointOfInterestTemplateDelegate {

    func pointOfInterestTemplate(
        _ pointOfInterestTemplate: CPPointOfInterestTemplate,
        didChangeMapRegion region: MKCoordinateRegion
    ) {
        // 地図移動時: 新しい中心座標で道の駅を再検索
        guard let service = stationService else { return }
        let center = region.center
        let heading = driveState?.heading ?? 0
        let speed = driveState?.speedKmh ?? 0
        service.updateNearbyStations(
            location: center,
            heading: heading,
            speedKmh: speed
        )

        // POI を更新
        let pois = buildPOIList()
        pointOfInterestTemplate.setPointsOfInterest(pois, selectedIndex: NSNotFound)
    }
}
