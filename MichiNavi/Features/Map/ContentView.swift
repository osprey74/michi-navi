//
//  ContentView.swift
//  MichiNavi
//
//  Created by 笹生総司 on 2026/03/08.
//

import SwiftUI
import MapKit

/// iPhone 側のメイン画面 — 現在地マップを表示
struct ContentView: View {

    @State private var locationService = LocationService()
    @State private var driveState = DriveState()

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // 速度表示オーバーレイ
            VStack {
                Text(driveState.speedText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(driveState.weatherDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 40)
        }
        .onAppear {
            locationService.requestAlwaysAuthorization()
        }
    }
}

#Preview {
    ContentView()
}
