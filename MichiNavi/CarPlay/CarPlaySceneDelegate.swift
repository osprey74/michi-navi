import CarPlay
import MapKit

/// CarPlay 画面のライフサイクルを管理するデリゲート
///
/// - Important: Driving Task カテゴリではテンプレート階層は最大 2 段まで。
///   走行中のテキスト入力や過度な情報表示は Apple 審査で却下される。
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?

    // MARK: - Scene Lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Root Template

    private func setupRootTemplate() {
        let rootTemplate = makeMainGridTemplate()
        interfaceController?.setRootTemplate(rootTemplate, animated: false, completion: nil)
    }

    // MARK: - Main Grid（メインメニュー）

    /// CarPlay メインメニュー（3項目: 目的地設定 / 周辺検索 / ドライブ情報）
    private func makeMainGridTemplate() -> CPGridTemplate {
        let destinationButton = CPGridButton(
            titleVariants: ["目的地設定", "目的地"],
            image: UIImage(systemName: "location.fill") ?? UIImage()
        ) { [weak self] _ in
            self?.showDestinationSearch()
        }

        let nearbyButton = CPGridButton(
            titleVariants: ["周辺を検索", "周辺"],
            image: UIImage(systemName: "magnifyingglass") ?? UIImage()
        ) { [weak self] _ in
            self?.showNearbyCategoryList()
        }

        let driveInfoButton = CPGridButton(
            titleVariants: ["ドライブ情報", "情報"],
            image: UIImage(systemName: "info.circle.fill") ?? UIImage()
        ) { [weak self] _ in
            self?.showDriveInfo()
        }

        return CPGridTemplate(
            title: "Michi-navi",
            gridButtons: [destinationButton, nearbyButton, driveInfoButton]
        )
    }

    // MARK: - 目的地設定

    /// 目的地は iPhone 側で入力し、結果を CarPlay に反映する
    private func showDestinationSearch() {
        let items = [
            CPListItem(text: "iPhone で目的地を入力してください", detailText: "Michi-navi アプリを開いて設定します"),
        ]
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "目的地設定", sections: [section])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - 周辺検索

    private func showNearbyCategoryList() {
        let categories: [(title: String, detail: String, icon: String)] = [
            ("給油所", "近くのガソリンスタンド", "fuelpump.fill"),
            ("SA / PA", "サービスエリア・パーキング", "car.fill"),
            ("コンビニ", "コンビニエンスストア", "bag.fill"),
            ("食事", "レストラン・ファストフード", "fork.knife"),
            ("駐車場", "近くの駐車場", "parkingsign"),
        ]

        let items = categories.map { category in
            CPListItem(
                text: category.title,
                detailText: category.detail,
                image: UIImage(systemName: category.icon)
            )
        }
        // TODO: Phase 1-B で MapKit POI 検索を実装
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "周辺を検索", sections: [section])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - ドライブ情報

    private func showDriveInfo() {
        // TODO: Phase 1-C で WeatherKit・LocationService の実データに差し替え
        let items = [
            CPInformationItem(title: "現在速度", detail: "-- km/h"),
            CPInformationItem(title: "天気", detail: "取得中..."),
            CPInformationItem(title: "気温", detail: "--°C"),
        ]

        let template = CPInformationTemplate(
            title: "ドライブ情報",
            layout: .leading,
            items: items,
            actions: []
        )
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }
}
