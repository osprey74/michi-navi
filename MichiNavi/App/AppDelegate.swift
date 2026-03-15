import UIKit
import CarPlay

class AppDelegate: NSObject, UIApplicationDelegate {

    /// CarPlaySceneDelegate など SwiftUI 外から参照するための静的プロパティ
    static private(set) var shared: AppDelegate?

    let locationService = LocationService()
    let driveState = DriveState()
    let stationService = RoadsideStationService()
    let navigationService = NavigationService()
    let appSettings = AppSettings()

    override init() {
        super.init()
        AppDelegate.shared = self
        stationService.loadStations()
        driveState.bind(to: locationService, stationService: stationService)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        locationService.requestAlwaysAuthorization()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        // CarPlay 接続時に専用の SceneDelegate を使用する
        if connectingSceneSession.role == UISceneSession.Role.carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        // iPhone 通常画面
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - iPhone SceneDelegate
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
}

