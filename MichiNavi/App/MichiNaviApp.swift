import SwiftUI

@main
struct MichiNaviApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.driveState)
                .environment(appDelegate.locationService)
                .environment(appDelegate.stationService)
                .environment(appDelegate.navigationService)
                .environment(appDelegate.appSettings)
                .environment(appDelegate.countrySignService)
                .environment(appDelegate.photoStore)
        }
    }
}
