import SwiftUI
import MapKit

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - 定数

private enum MapConstants {
    /// 現在地ボタンのズーム幅 ≈ 200 km
    static let locationButtonZoom: Double = 200 * 0.009   // 1.8°
    /// 起動時・広域ズーム ≈ 120 km
    static let wideZoom: Double = 120 * 0.009           // 1.08°
}

/// iPhone 側のメイン画面 — カスタムタイルマップ + 道の駅ピン
struct ContentView: View {

    @Environment(DriveState.self) private var driveState
    @Environment(LocationService.self) private var locationService
    @Environment(RoadsideStationService.self) private var stationService
    @Environment(NavigationService.self) private var navigationService
    @Environment(AppSettings.self) private var settings
    @Environment(CountrySignService.self) private var signService

    @State private var selectedStation: RoadsideStation?
    @State private var selectedSign: CountrySign?
    @State private var commandedRegion: MKCoordinateRegion?

    @State private var autoZoomEnabled = true
    @State private var autoZoomResumeTask: Task<Void, Never>?
    @State private var initialZoomApplied = false
    @State private var currentZoom: Double = MapConstants.wideZoom

    @State private var showSettings = false
    @State private var showCombinedList = false

    var body: some View {
        ZStack {
            CustomMapView(
                tileType: settings.selectedMapTile,
                googleAPIKey: settings.googleMapsAPIKey,
                stations: settings.showStationMarkers ? stationService.visibleStations : [],
                favoriteIds: settings.favoriteStationIds,
                visitedIds: settings.visitedStationIds,
                countrySigns: settings.showCountrySignMarkers ? signService.allSigns : [],
                favoriteSignIds: settings.favoriteSignIds,
                visitedSignIds: settings.visitedSignIds,
                boundaryOverlays: signService.boundaryOverlays,
                showBoundaries: settings.showCountrySignMarkers,
                selectedStation: $selectedStation,
                selectedSign: $selectedSign,
                commandedRegion: $commandedRegion
            ) { region in
                stationService.updateVisibleStations(
                    center: region.center,
                    latitudeDelta: region.span.latitudeDelta,
                    longitudeDelta: region.span.longitudeDelta
                )
            }
            .ignoresSafeArea()

            overlayControls
        }
        .sheet(item: $selectedStation) { station in
            StationDetailSheet(station: station)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedSign) { sign in
            CountrySignDetailSheet(sign: sign)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCombinedList) {
            CombinedListsView()
        }
        .onChange(of: showCombinedList) { _, isShowing in
            guard !isShowing else { return }
            let span = 20.0 * 0.009
            if let station = settings.mapFocusStation {
                commandedRegion = MKCoordinateRegion(
                    center: station.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
                pauseAutoZoom()
                settings.mapFocusStation = nil
            } else if let sign = settings.mapFocusSign {
                commandedRegion = MKCoordinateRegion(
                    center: sign.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
                pauseAutoZoom()
                settings.mapFocusSign = nil
            }
        }
        .onChange(of: driveState.currentLocation) { _, newLocation in
            guard let loc = newLocation else { return }

            if !initialZoomApplied {
                initialZoomApplied = true
                commandedRegion = MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: MapConstants.wideZoom,
                                          longitudeDelta: MapConstants.wideZoom)
                )
                return
            }

            guard autoZoomEnabled else { return }
            let speed = driveState.speedKmh
            let newZoom = Self.zoomLevel(forSpeed: speed)

            if abs(newZoom - currentZoom) / currentZoom > 0.3 {
                currentZoom = newZoom
                if speed > 5 {
                    commandedRegion = MKCoordinateRegion(
                        center: loc,
                        span: MKCoordinateSpan(latitudeDelta: newZoom, longitudeDelta: newZoom)
                    )
                }
            }
        }
        .onAppear {
            if let loc = driveState.currentLocation, !initialZoomApplied {
                initialZoomApplied = true
                commandedRegion = MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: MapConstants.wideZoom,
                                          longitudeDelta: MapConstants.wideZoom)
                )
            }
        }
    }

    // MARK: - オーバーレイ

    private var overlayControls: some View {
        VStack {
            // 上部ボタン行
            HStack {
                Button { showSettings = true } label: {
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

            // 下部: 速度情報 + リスト + 現在地
            HStack(alignment: .bottom) {
                // 速度・天気パネル
                VStack(spacing: 4) {
                    Text(driveState.speedText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(driveState.weatherDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                // リスト + マーカートグル + 現在地ボタン
                VStack(spacing: 8) {
                    // 統合リスト
                    Button {
                        showCombinedList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(.primary)

                    // 道の駅マーカートグル
                    Button {
                        settings.showStationMarkers.toggle()
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(settings.showStationMarkers ? .blue : .primary)

                    // カントリーサインマーカートグル
                    Button {
                        settings.showCountrySignMarkers.toggle()
                    } label: {
                        Image(systemName: "signpost.right.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(settings.showCountrySignMarkers ? .blue : .primary)

                    // 現在地
                    Button {
                        centerOnUserLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 30)
        }
    }

    // MARK: - 現在地ボタン

    private func centerOnUserLocation() {
        guard let loc = driveState.currentLocation else { return }
        pauseAutoZoom()
        currentZoom = MapConstants.locationButtonZoom
        commandedRegion = MKCoordinateRegion(
            center: loc,
            span: MKCoordinateSpan(latitudeDelta: MapConstants.locationButtonZoom,
                                   longitudeDelta: MapConstants.locationButtonZoom)
        )
    }

    // MARK: - 速度→縮尺マッピング

    static func zoomLevel(forSpeed speed: Double) -> Double {
        let full = MapConstants.wideZoom
        switch speed {
        case ..<5:   return full
        case ..<30:  return full * 0.15
        case ..<60:  return full * 0.3
        case ..<100: return full * 0.5
        default:     return full * 0.7
        }
    }

    private func pauseAutoZoom() {
        autoZoomEnabled = false
        autoZoomResumeTask?.cancel()
        autoZoomResumeTask = Task {
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled {
                await MainActor.run { autoZoomEnabled = true }
            }
        }
    }
}

// MARK: - 統合リストシート

struct CombinedListsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ListTab = .stations

    enum ListTab: String, CaseIterable {
        case stations = "道の駅"
        case countrySigns = "カントリーサイン"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(ListTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                switch selectedTab {
                case .stations:
                    StationListsContent()
                case .countrySigns:
                    CountrySignListsContent()
                }
            }
            .navigationTitle("リスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
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

// MARK: - カントリーサイン詳細シート

struct CountrySignDetailSheet: View {
    let sign: CountrySign
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CountrySignDetailView(sign: sign)
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
        .environment(CountrySignService())
}
