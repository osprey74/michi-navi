//
//  ContentView.swift
//  MichiNavi
//
//  Created by 笹生総司 on 2026/03/08.
//

import SwiftUI
import MapKit

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

/// iPhone 側のメイン画面 — 現在地マップ + 道の駅リスト
struct ContentView: View {

    @Environment(DriveState.self) private var driveState
    @Environment(LocationService.self) private var locationService
    @Environment(RoadsideStationService.self) private var stationService
    @Environment(NavigationService.self) private var navigationService
    @Environment(AppSettings.self) private var settings

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStation: NearbyStation?
    @State private var zoomLevel: Double = 0.05  // 緯度方向の表示幅（度）
    @State private var showSettings = false
    @State private var showDestinationPicker = false
    @State private var autoZoomEnabled = true
    @State private var autoZoomResumeTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // 地図 + 道の駅ピン
            Map(position: $position) {
                UserAnnotation()
                ForEach(stationService.nearbyStations) { nearby in
                    Annotation(nearby.station.name, coordinate: nearby.station.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)
                            .onTapGesture { selectedStation = nearby }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // オーバーレイ
            VStack {
                // 上部: 設定ボタン
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                // 下部: 速度 + ズーム + 目的地 + 道の駅リスト
                HStack(alignment: .bottom, spacing: 12) {
                    if settings.zoomPosition == .left {
                        // 左: ズーム + 道の駅リスト / 右: 速度 + 目的地
                        leftSideControls
                        Spacer()
                        rightSideInfo
                    } else {
                        // 左: 速度 + 目的地 / 右: ズーム + 道の駅リスト
                        leftSideInfo
                        Spacer()
                        rightSideControls
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $selectedStation) { nearby in
            StationDetailSheet(nearby: nearby)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showDestinationPicker) {
            DestinationPickerView()
        }
        .onChange(of: driveState.currentLocation) { _, newLocation in
            guard autoZoomEnabled, let loc = newLocation else { return }
            let speed = driveState.speedKmh
            let newZoom = Self.zoomLevel(forSpeed: speed)

            // 速度による縮尺変更があれば適用
            if abs(newZoom - zoomLevel) / zoomLevel > 0.3 {
                zoomLevel = newZoom
            }

            // 移動中は現在地に追従
            if speed > 5 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    position = .region(MKCoordinateRegion(
                        center: loc,
                        span: MKCoordinateSpan(latitudeDelta: zoomLevel, longitudeDelta: zoomLevel)
                    ))
                }
            }
        }
    }

    // MARK: - 速度→縮尺マッピング

    /// 速度(km/h)に応じた地図の表示幅(緯度方向・度)を返す
    static func zoomLevel(forSpeed speed: Double) -> Double {
        switch speed {
        case ..<5:    return 0.01   // 停車中: 約1km四方
        case ..<30:   return 0.02   // 市街地: 約2km四方
        case ..<60:   return 0.05   // 一般道: 約5km四方
        case ..<100:  return 0.1    // 高速道: 約10km四方
        default:      return 0.2    // 高速巡航: 約20km四方
        }
    }

    /// 手動ズーム操作時に自動調整を一時停止し、30秒後に再開する
    func pauseAutoZoom() {
        autoZoomEnabled = false
        autoZoomResumeTask?.cancel()
        autoZoomResumeTask = Task {
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled {
                await MainActor.run { autoZoomEnabled = true }
            }
        }
    }

    // MARK: - ズーム側（ズームボタン + 道の駅リスト）

    private var leftSideControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            destinationButton
            MapZoomControls(position: $position, zoomLevel: $zoomLevel, driveState: driveState, onManualZoom: pauseAutoZoom)
            if !stationService.nearbyStations.isEmpty {
                StationListPanel(stations: stationService.nearbyStations, selectedStation: $selectedStation)
            }
        }
    }

    private var rightSideControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            destinationButton
            MapZoomControls(position: $position, zoomLevel: $zoomLevel, driveState: driveState, onManualZoom: pauseAutoZoom)
            if !stationService.nearbyStations.isEmpty {
                StationListPanel(stations: stationService.nearbyStations, selectedStation: $selectedStation)
            }
        }
    }

    // MARK: - 情報側（速度表示）

    private var leftSideInfo: some View {
        VStack(spacing: 4) {
            Text(driveState.speedText)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(driveState.weatherDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var rightSideInfo: some View {
        VStack(spacing: 4) {
            Text(driveState.speedText)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(driveState.weatherDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 目的地ボタン

    private var destinationButton: some View {
        Button {
            showDestinationPicker = true
        } label: {
            Image(systemName: "flag.fill")
                .font(.title3.bold())
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 拡大縮小ボタン

struct MapZoomControls: View {
    @Binding var position: MapCameraPosition
    @Binding var zoomLevel: Double
    let driveState: DriveState
    var onManualZoom: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Button {
                zoom(by: 0.5) // 拡大
            } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
            }

            Divider()

            Button {
                zoom(by: 2.0) // 縮小
            } label: {
                Image(systemName: "minus")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
            }
        }
        .frame(width: 44)
        .fixedSize()
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func zoom(by factor: Double) {
        onManualZoom?()
        let newZoom = max(0.002, min(5.0, zoomLevel * factor))
        zoomLevel = newZoom

        let center: CLLocationCoordinate2D
        if let loc = driveState.currentLocation {
            center = loc
        } else {
            center = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.77)
        }

        position = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: newZoom, longitudeDelta: newZoom)
        ))
    }
}

// MARK: - 道の駅リストパネル

struct StationListPanel: View {
    let stations: [NearbyStation]
    @Binding var selectedStation: NearbyStation?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("前方の道の駅")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(stations.prefix(5)) { nearby in
                        Button {
                            selectedStation = nearby
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(nearby.station.name)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Text(nearby.station.roadName ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(nearby.distanceText)
                                        .font(.caption.bold())
                                    Text(nearby.cardinalDirection)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 180)

            Text("前方 \(stations.count) 件")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 道の駅詳細シート

struct StationDetailSheet: View {
    let nearby: NearbyStation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StationDetailView(station: nearby.station, nearby: nearby)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(DriveState())
        .environment(LocationService())
        .environment(RoadsideStationService())
        .environment(NavigationService())
        .environment(AppSettings())
}
