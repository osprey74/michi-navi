//
//  ContentView.swift
//  MichiNavi
//
//  Created by 笹生総司 on 2026/03/08.
//

import SwiftUI
import MapKit

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
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
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
    }

    // MARK: - ズーム側（ズームボタン + 道の駅リスト）

    private var leftSideControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            destinationButton
            MapZoomControls(position: $position, zoomLevel: $zoomLevel, driveState: driveState)
            if !stationService.nearbyStations.isEmpty {
                StationListPanel(stations: stationService.nearbyStations, selectedStation: $selectedStation)
            }
        }
    }

    private var rightSideControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            destinationButton
            MapZoomControls(position: $position, zoomLevel: $zoomLevel, driveState: driveState)
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
    @Environment(NavigationService.self) private var navigationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("距離", value: nearby.distanceText)
                    LabeledContent("方角", value: nearby.cardinalDirection)
                    LabeledContent("路線", value: nearby.station.roadName ?? "不明")
                    LabeledContent("所在地", value: "\(nearby.station.prefecture ?? "") \(nearby.station.municipality ?? "")")
                }

                if !nearby.station.features.isEmpty {
                    Section("施設") {
                        let featureLabels = nearby.station.features.map { featureLabel(for: $0) }
                        Text(featureLabels.joined(separator: "、"))
                            .font(.subheadline)
                    }
                }

                if let urlString = nearby.station.url, let url = URL(string: urlString) {
                    Section {
                        Link("公式サイトを開く", destination: url)
                    }
                }

                Section {
                    Button {
                        navigationService.navigateInAppleMaps(to: nearby.station)
                    } label: {
                        Label("この道の駅へナビ開始", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle(nearby.station.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func featureLabel(for key: String) -> String {
        switch key {
        case "atm": return "ATM"
        case "restaurant": return "レストラン"
        case "onsen": return "温泉"
        case "ev_charger": return "EV充電"
        case "wifi": return "Wi-Fi"
        case "baby_room": return "授乳室"
        case "disabled_toilet": return "障害者トイレ"
        case "information": return "情報コーナー"
        case "shop": return "物販"
        case "experience": return "体験施設"
        case "museum": return "資料館"
        case "park": return "公園"
        case "hotel": return "宿泊"
        case "rv_park": return "RVパーク"
        case "dog_run": return "ドッグラン"
        case "bicycle_rental": return "レンタサイクル"
        case "camping": return "キャンプ"
        case "footbath": return "足湯"
        default: return key
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
