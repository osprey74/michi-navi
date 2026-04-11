import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    let locationService = LocationService()
    let driveState = DriveState()
    let stationService = RoadsideStationService()
    let navigationService = NavigationService()
    let appSettings = AppSettings()
    let countrySignService = CountrySignService()
    let photoStore = StationPhotoStore()

    override init() {
        super.init()
        stationService.loadStations()
        countrySignService.loadData()
        driveState.bind(to: locationService, stationService: stationService)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        locationService.requestAlwaysAuthorization()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // 他端末での変更を反映するため、フォアグラウンド復帰時に KVS を再読み込み
        appSettings.reloadFromKVS()
    }
}
