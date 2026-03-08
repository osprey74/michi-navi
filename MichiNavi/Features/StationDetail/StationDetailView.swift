import SwiftUI

/// 道の駅詳細の共通ビュー（写真・施設グリッド・基本情報・ナビボタン）
///
/// ContentView のシート表示と DestinationPickerView のナビゲーション遷移の両方で使用する。
struct StationDetailView: View {

    let station: RoadsideStation
    let nearby: NearbyStation?
    @Environment(NavigationService.self) private var navigationService

    init(station: RoadsideStation, nearby: NearbyStation? = nil) {
        self.station = station
        self.nearby = nearby
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    var body: some View {
        List {
            // 写真セクション
            if let imageUrlString = station.imageUrl, let imageUrl = URL(string: imageUrlString) {
                Section {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            photoPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        @unknown default:
                            photoPlaceholder
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
            }

            // 基本情報セクション
            Section {
                if let nearby {
                    LabeledContent("距離", value: nearby.distanceText)
                    LabeledContent("方角", value: nearby.cardinalDirection)
                }
                LabeledContent("路線", value: station.roadName ?? "不明")
                LabeledContent("所在地", value: [station.prefecture, station.municipality]
                    .compactMap { $0 }
                    .joined(separator: " "))
            }

            // 施設設備セクション（アイコングリッド）
            if !station.featureInfos.isEmpty {
                Section("施設・設備") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(station.featureInfos, id: \.key) { info in
                            VStack(spacing: 4) {
                                Image(systemName: info.icon)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                Text(info.label)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(minWidth: 70, minHeight: 50)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // 公式サイトリンク
            if let urlString = station.url, let url = URL(string: urlString) {
                Section {
                    Link(destination: url) {
                        Label("公式サイトを開く", systemImage: "safari")
                    }
                }
            }

            // ナビ開始ボタン
            Section {
                Button {
                    navigationService.navigateInAppleMaps(to: station)
                } label: {
                    Label("この道の駅へナビ開始", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var photoPlaceholder: some View {
        ZStack {
            Color(.systemGroupedBackground)
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("写真なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}
