//
//  MichiNaviApp.swift
//  MichiNavi
//
//  Created by 笹生総司 on 2026/03/08.
//

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
        }
    }
}
