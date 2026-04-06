import CarPlay
import MapKit

/// CarPlay 画面のライフサイクルを管理するデリゲート
///
/// - Important: Driving Task カテゴリではテンプレート階層は最大 2 段まで。
///   使用可能なテンプレート: CPListTemplate / CPGridTemplate / CPInformationTemplate /
///   CPAlertTemplate / CPActionSheetTemplate
///   ※ CPPointOfInterestTemplate は Parking / EV / Food 専用のため使用不可。
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var rootListTemplate: CPListTemplate?
    private var driveInfoTemplate: CPInformationTemplate?
    private var updateTimer: Timer?

    // MARK: - 共有状態

    private var driveState: DriveState? { AppDelegate.shared?.driveState }
    private var stationService: RoadsideStationService? { AppDelegate.shared?.stationService }
    private var navigationService: NavigationService? { AppDelegate.shared?.navigationService }
    private var appSettings: AppSettings? { AppDelegate.shared?.appSettings }

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

    /// お気に入り・到達状態に合わせたアイコンを返す
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

    // MARK: - Root Template（CPListTemplate）

    private func setupRootTemplate() {
        let template = buildRootListTemplate()
        self.rootListTemplate = template
        interfaceController?.setRootTemplate(template, animated: false, completion: nil)
    }

    private func buildRootListTemplate() -> CPListTemplate {
        let template = buildStationSections()

        // ドライブ情報ボタン（右上）
        let infoButton = CPBarButton(image: UIImage(systemName: "gauge.with.dots.needle.50percent") ?? UIImage()) { [weak self] _ in
            self?.showDriveInfo()
        }
        template.trailingNavigationBarButtons = [infoButton]

        return template
    }

    private func buildStationSections() -> CPListTemplate {
        let favIds = appSettings?.favoriteStationIds ?? []
        let visIds = appSettings?.visitedStationIds ?? []

        // 走行情報セクション
        let speedText = driveState?.speedText ?? "-- km/h"
        let speedItem = CPListItem(
            text: speedText,
            detailText: "現在速度",
            image: UIImage(systemName: "speedometer")
        )
        let speedSection = CPListSection(items: [speedItem], header: "走行情報", sectionIndexTitle: nil)

        // 前方の道の駅セクション
        let nearbyItems: [CPListItem]
        let stations = stationService?.nearbyStations ?? []
        if stations.isEmpty {
            let placeholder = CPListItem(text: "周辺の道の駅を検索中...", detailText: "位置情報を確認しています")
            nearbyItems = [placeholder]
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
                    self?.showNavAppPicker(for: nearby.station)
                    completion()
                }
                return item
            }
        }
        let nearbySection = CPListSection(items: nearbyItems, header: "前方の道の駅", sectionIndexTitle: nil)

        // お気に入りセクション（登録済みのみ）
        var sections: [CPListSection] = [speedSection, nearbySection]
        let allStations = stationService?.allStations ?? []
        let favStations = allStations.filter { favIds.contains($0.id) }
        if !favStations.isEmpty {
            let favItems = favStations.prefix(10).map { station -> CPListItem in
                let isVis = visIds.contains(station.id)
                let item = CPListItem(
                    text: station.name,
                    detailText: station.roadName ?? "",
                    image: stationIcon(isFavorite: true, isVisited: isVis, size: 20)
                )
                item.handler = { [weak self] _, completion in
                    self?.showNavAppPicker(for: station)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: favItems, header: "お気に入り", sectionIndexTitle: nil))
        }

        return CPListTemplate(title: "道の駅", sections: sections)
    }

    // MARK: - ドライブ情報（CPInformationTemplate）

    private func showDriveInfo() {
        let template = buildDriveInfoTemplate()
        self.driveInfoTemplate = template
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func buildDriveInfoTemplate() -> CPInformationTemplate {
        let state = driveState
        let items = [
            CPInformationItem(title: "現在速度",  detail: state?.speedText          ?? "-- km/h"),
            CPInformationItem(title: "天気",      detail: state?.weatherDescription ?? "取得中..."),
            CPInformationItem(title: "気温",      detail: state?.temperatureText    ?? "--°C"),
        ]
        return CPInformationTemplate(title: "ドライブ情報", layout: .leading, items: items, actions: [])
    }

    // MARK: - ナビアプリ選択（CPActionSheetTemplate）

    private func showNavAppPicker(for station: RoadsideStation) {
        guard let nav = navigationService else { return }
        let apps = nav.availableApps()

        if apps.count == 1 {
            nav.navigate(to: station, with: .appleMaps)
            return
        }

        let appActions = apps.map { app -> CPAlertAction in
            CPAlertAction(title: app.displayName, style: .default) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                nav.navigate(to: station, with: app)
            }
        }
        let cancelAction = CPAlertAction(title: "キャンセル", style: .cancel) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        let sheet = CPActionSheetTemplate(
            title: "ナビアプリを選択",
            message: station.name,
            actions: appActions + [cancelAction]
        )
        interfaceController?.presentTemplate(sheet, animated: true, completion: nil)
    }

    // MARK: - 自動更新

    private func startAutoUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshTemplates()
        }
    }

    private func stopAutoUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refreshTemplates() {
        // ルートリスト更新
        if let template = rootListTemplate {
            let rebuilt = buildStationSections()
            template.updateSections(rebuilt.sections)
        }

        // ドライブ情報更新（表示中の場合）
        if let state = driveState, let template = driveInfoTemplate {
            template.items = [
                CPInformationItem(title: "現在速度",  detail: state.speedText),
                CPInformationItem(title: "天気",      detail: state.weatherDescription),
                CPInformationItem(title: "気温",      detail: state.temperatureText),
            ]
        }
    }
}
