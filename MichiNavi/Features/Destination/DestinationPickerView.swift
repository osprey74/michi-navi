import SwiftUI
import MapKit

/// 道の駅を都道府県→市町村→道の駅の3階層で選択する画面
struct DestinationPickerView: View {

    @Environment(RoadsideStationService.self) private var stationService
    @Environment(NavigationService.self) private var navigationService
    @Environment(\.dismiss) private var dismiss

    /// 地方ごとの都道府県グループ
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
        NavigationStack {
            List {
                ForEach(Self.regions, id: \.name) { region in
                    let available = region.prefectures.filter {
                        stationService.availablePrefectures.contains($0)
                    }
                    if !available.isEmpty {
                        Section(region.name) {
                            ForEach(available, id: \.self) { pref in
                                let count = stationService.stations(in: pref).count
                                NavigationLink {
                                    MunicipalityListView(prefecture: pref)
                                } label: {
                                    HStack {
                                        Text(pref)
                                        Spacer()
                                        Text("\(count) 駅")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("目的地を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 市町村リスト

struct MunicipalityListView: View {

    let prefecture: String
    @Environment(RoadsideStationService.self) private var stationService

    var body: some View {
        let municipalities = stationService.municipalities(in: prefecture)

        List {
            // 全件表示
            NavigationLink {
                StationPickerListView(prefecture: prefecture, municipality: nil)
            } label: {
                HStack {
                    Text("すべて")
                        .bold()
                    Spacer()
                    Text("\(stationService.stations(in: prefecture).count) 駅")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            ForEach(municipalities, id: \.self) { muni in
                let count = stationService.stations(in: prefecture, municipality: muni).count
                NavigationLink {
                    StationPickerListView(prefecture: prefecture, municipality: muni)
                } label: {
                    HStack {
                        Text(muni)
                        Spacer()
                        Text("\(count) 駅")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(prefecture)
    }
}

// MARK: - 道の駅リスト

struct StationPickerListView: View {

    let prefecture: String
    let municipality: String?
    @Environment(RoadsideStationService.self) private var stationService

    var body: some View {
        let stations = stationService.stations(in: prefecture, municipality: municipality)

        List(stations) { station in
            NavigationLink {
                StationPickerDetailView(station: station)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.body)
                    Text(station.roadName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(municipality ?? prefecture)
    }
}

// MARK: - 道の駅詳細（ナビ開始ボタン付き）

struct StationPickerDetailView: View {

    let station: RoadsideStation
    @Environment(NavigationService.self) private var navigationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                LabeledContent("路線", value: station.roadName ?? "不明")
                LabeledContent("所在地", value: "\(station.prefecture ?? "") \(station.municipality ?? "")")
            }

            if !station.features.isEmpty {
                Section("施設") {
                    Text(station.features.map { featureLabel(for: $0) }.joined(separator: "、"))
                        .font(.subheadline)
                }
            }

            if let urlString = station.url, let url = URL(string: urlString) {
                Section {
                    Link("公式サイトを開く", destination: url)
                }
            }

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
