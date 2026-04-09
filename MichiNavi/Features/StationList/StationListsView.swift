import SwiftUI

/// 道の駅リスト・お気に入りリスト・踏破リストの3タブシート
struct StationListsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StationListsContent()
                .navigationTitle("道の駅リスト")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

/// 統合リストビューから再利用可能な道の駅タブコンテンツ
struct StationListsContent: View {
    var body: some View {
        TabView {
            AllStationsTab()
                .tabItem { Label("道の駅", systemImage: "building.2.fill") }
            FavoriteStationsTab()
                .tabItem { Label("お気に入り", systemImage: "heart.fill") }
            VisitedStationsTab()
                .tabItem { Label("踏破済み", systemImage: "checkmark.seal.fill") }
        }
    }
}

// MARK: - Tab 1: 全道の駅（地域→都道府県→市町村→詳細）

private struct AllStationsTab: View {
    @Environment(RoadsideStationService.self) private var stationService

    private static let regions: [(name: String, prefectures: [String])] = [
        ("北海道地方", ["北海道"]),
        ("東北地方", ["青森県","岩手県","宮城県","秋田県","山形県","福島県"]),
        ("関東地方", ["茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県"]),
        ("中部地方", ["新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜県","静岡県","愛知県"]),
        ("近畿地方", ["三重県","滋賀県","京都府","大阪府","兵庫県","奈良県","和歌山県"]),
        ("中国地方", ["鳥取県","島根県","岡山県","広島県","山口県"]),
        ("四国地方", ["徳島県","香川県","愛媛県","高知県"]),
        ("九州・沖縄地方", ["福岡県","佐賀県","長崎県","熊本県","大分県","宮崎県","鹿児島県","沖縄県"]),
    ]

    var body: some View {
        List {
            ForEach(Self.regions, id: \.name) { region in
                let available = region.prefectures.filter {
                    stationService.availablePrefectures.contains($0)
                }
                if !available.isEmpty {
                    Section(region.name) {
                        ForEach(available, id: \.self) { pref in
                            NavigationLink {
                                MunicipalityListView(prefecture: pref)
                            } label: {
                                HStack {
                                    Text(pref)
                                    Spacer()
                                    Text("\(stationService.stations(in: pref).count) 駅")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 2: お気に入りリスト

private struct FavoriteStationsTab: View {
    @Environment(RoadsideStationService.self) private var stationService
    @Environment(AppSettings.self) private var settings

    private var favoriteStations: [RoadsideStation] {
        stationService.allStations
            .filter { settings.favoriteStationIds.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if favoriteStations.isEmpty {
                ContentUnavailableView {
                    Label("お気に入りなし", systemImage: "heart")
                } description: {
                    Text("詳細画面でハートボタンをタップすると追加されます")
                }
            } else {
                List(favoriteStations) { station in
                    NavigationLink {
                        StationDetailView(station: station)
                    } label: {
                        StationListRow(station: station)
                    }
                }
            }
        }
    }
}

// MARK: - Tab 3: 踏破リスト

private struct VisitedStationsTab: View {
    @Environment(RoadsideStationService.self) private var stationService
    @Environment(AppSettings.self) private var settings

    private var visitedStations: [RoadsideStation] {
        stationService.allStations
            .filter { settings.visitedStationIds.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if visitedStations.isEmpty {
                ContentUnavailableView {
                    Label("踏破記録なし", systemImage: "checkmark.seal")
                } description: {
                    Text("詳細画面でチェックボタンをタップすると追加されます")
                }
            } else {
                List(visitedStations) { station in
                    NavigationLink {
                        StationDetailView(station: station)
                    } label: {
                        StationListRow(station: station)
                    }
                }
            }
        }
    }
}

// MARK: - 共通リスト行

struct StationListRow: View {
    let station: RoadsideStation
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 8) {
            let isFav = settings.favoriteStationIds.contains(station.id)
            let isVis = settings.visitedStationIds.contains(station.id)
            statusIcon(isFav: isFav, isVis: isVis)

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.body)
                Text([station.prefecture, station.roadName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(isFav: Bool, isVis: Bool) -> some View {
        switch (isFav, isVis) {
        case (true, true):
            Image(systemName: "checkmark.shield.fill").foregroundStyle(.red)
        case (true, false):
            Image(systemName: "heart.circle.fill").foregroundStyle(.red)
        case (false, true):
            Image(systemName: "checkmark.shield.fill").foregroundStyle(.blue)
        case (false, false):
            Image(systemName: "mappin.circle.fill").foregroundStyle(.orange)
        }
    }
}
