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

// MARK: - 定数

private enum MapConstants {
    /// 広域表示: 短辺120km
    static let wideZoom: Double = 120 * 0.009  // 1.08°
    /// 詳細表示: 短辺300m
    static let detailZoom: Double = 0.3 * 0.009  // 0.0027°
}

/// iPhone 側のメイン画面 — 現在地マップ + 道の駅ピン
struct ContentView: View {

    @Environment(DriveState.self) private var driveState
    @Environment(LocationService.self) private var locationService
    @Environment(RoadsideStationService.self) private var stationService
    @Environment(NavigationService.self) private var navigationService
    @Environment(AppSettings.self) private var settings

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStation: RoadsideStation?
    @State private var zoomLevel: Double = MapConstants.wideZoom
    @State private var showSettings = false
    @State private var showDestinationPicker = false
    @State private var showRVParkSearch = false
    @State private var showDestinationMenu = false
    @State private var autoZoomEnabled = true
    @State private var autoZoomResumeTask: Task<Void, Never>?
    @State private var initialZoomApplied = false
    @State private var mapSelection: MapFeature?

    var body: some View {
        ZStack {
            // 地図 + 道の駅ピン（表示領域フィルタ）
            Map(position: $position, selection: $mapSelection) {
                UserAnnotation()
                ForEach(stationService.visibleStations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)
                            .onTapGesture { selectedStation = station }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: poiCategories))
            .mapFeatureSelectionAccessory(.automatic)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                let region = context.region
                stationService.updateVisibleStations(
                    center: region.center,
                    latitudeDelta: region.span.latitudeDelta,
                    longitudeDelta: region.span.longitudeDelta
                )
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

                // 下部: 速度 + ズーム + 目的地
                HStack(alignment: .bottom, spacing: 12) {
                    if settings.zoomPosition == .left {
                        leftSideControls
                        Spacer()
                        rightSideInfo
                    } else {
                        leftSideInfo
                        Spacer()
                        rightSideControls
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $selectedStation) { station in
            StationDetailSheet(station: station)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showDestinationPicker) {
            DestinationPickerView()
        }
        .sheet(isPresented: $showRVParkSearch) {
            RVParkSearchView()
        }
        .onChange(of: driveState.currentLocation) { _, newLocation in
            guard let loc = newLocation else { return }

            // 初回の位置情報取得時に120km縮尺を適用
            if !initialZoomApplied {
                initialZoomApplied = true
                zoomLevel = MapConstants.wideZoom
                position = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: zoomLevel, longitudeDelta: zoomLevel)
                ))
                return
            }

            guard autoZoomEnabled else { return }
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
        .onAppear {
            zoomLevel = MapConstants.wideZoom
            if let loc = driveState.currentLocation {
                position = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: zoomLevel, longitudeDelta: zoomLevel)
                ))
                initialZoomApplied = true
            }
        }

    }

    // MARK: - POIカテゴリ

    /// 設定に基づく地図上のPOI表示カテゴリ
    private var poiCategories: PointOfInterestCategories {
        var categories: [MKPointOfInterestCategory] = []
        if settings.showGasStations { categories.append(.gasStation) }
        if settings.showFoodMarkets { categories.append(.foodMarket) }
        if settings.showRestaurants { categories.append(.restaurant); categories.append(.cafe) }
        if settings.showParking { categories.append(.parking) }
        if settings.showRVParks { categories.append(.rvPark); categories.append(.campground) }

        if categories.isEmpty {
            return .excludingAll
        }
        return .including(categories)
    }

    // MARK: - 速度→縮尺マッピング

    /// 速度(km/h)に応じた地図の表示幅(緯度方向・度)を返す
    /// ベースは広域120km (1.08°)
    static func zoomLevel(forSpeed speed: Double) -> Double {
        let fullSpan = MapConstants.wideZoom
        switch speed {
        case ..<5:    return fullSpan
        case ..<30:   return fullSpan * 0.15
        case ..<60:   return fullSpan * 0.3
        case ..<100:  return fullSpan * 0.5
        default:      return fullSpan * 0.7
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

    /// 指定のズームレベルに移動
    private func applyZoom(_ newZoom: Double) {
        pauseAutoZoom()
        zoomLevel = newZoom
        let center = driveState.currentLocation ?? CLLocationCoordinate2D(latitude: 35.68, longitude: 139.77)
        withAnimation(.easeInOut(duration: 0.3)) {
            position = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: newZoom, longitudeDelta: newZoom)
            ))
        }
    }

    // MARK: - コントロール側（ズームボタン + 目的地）

    private var leftSideControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            destinationButton
            zoomPresetButtons
        }
    }

    private var rightSideControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            destinationButton
            zoomPresetButtons
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

    // MARK: - 広域・詳細ボタン

    private var zoomPresetButtons: some View {
        VStack(spacing: 0) {
            Button {
                applyZoom(MapConstants.wideZoom)
            } label: {
                Text("広域")
                    .font(.caption.bold())
                    .frame(width: 44, height: 44)
            }

            Divider()

            Button {
                applyZoom(MapConstants.detailZoom)
            } label: {
                Text("詳細")
                    .font(.caption.bold())
                    .frame(width: 44, height: 44)
            }
        }
        .frame(width: 44)
        .fixedSize()
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 目的地ボタン（道の駅/RVパーク切替メニュー）

    private var destinationButton: some View {
        Menu {
            Button {
                showDestinationPicker = true
            } label: {
                Label("道の駅", systemImage: "mappin.circle.fill")
            }
            Button {
                showRVParkSearch = true
            } label: {
                Label("RVパーク", systemImage: "tent.fill")
            }
        } label: {
            Image(systemName: "flag.fill")
                .font(.title3.bold())
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 道の駅詳細シート

struct StationDetailSheet: View {
    let station: RoadsideStation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StationDetailView(station: station)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - RVパーク検索画面

struct RVParkSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DriveState.self) private var driveState
    @Environment(NavigationService.self) private var navigationService

    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("検索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("検索エラー", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("RVパークが見つかりません", systemImage: "tent.fill")
                    } description: {
                        Text("周辺にRVパーク・キャンプ場が見つかりませんでした")
                    }
                } else {
                    List(searchResults, id: \.self) { item in
                        Button {
                            navigationService.navigateInAppleMaps(to: item)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "不明")
                                    .font(.body.bold())
                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if let phone = item.phoneNumber {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("RVパーク検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await searchRVParks()
            }
        }
    }

    private func searchRVParks() async {
        guard let location = driveState.currentLocation else {
            errorMessage = "位置情報が取得できません"
            return
        }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "RVパーク キャンプ場"
        request.region = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.rvPark, .campground])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            errorMessage = "検索に失敗しました: \(error.localizedDescription)"
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
