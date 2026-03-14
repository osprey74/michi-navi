import SwiftUI

/// 設定画面
struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("道の駅 検索範囲") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("検索距離")
                            Spacer()
                            Text("\(Int(settings.searchRadiusKm)) km")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $settings.searchRadiusKm,
                            in: 50...400,
                            step: 10
                        ) {
                            Text("検索距離")
                        } minimumValueLabel: {
                            Text("50")
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text("400")
                                .font(.caption2)
                        }
                    }
                }

                Section("地図上に表示する施設") {
                    Toggle(isOn: $settings.showGasStations) {
                        Label("ガソリンスタンド", systemImage: "fuelpump.fill")
                    }
                    Toggle(isOn: $settings.showFoodMarkets) {
                        Label("コンビニ・スーパー", systemImage: "cart.fill")
                    }
                    Toggle(isOn: $settings.showRestaurants) {
                        Label("レストラン・カフェ", systemImage: "fork.knife")
                    }
                    Toggle(isOn: $settings.showParking) {
                        Label("駐車場", systemImage: "p.square.fill")
                    }
                }

                Section("ズームボタン位置") {
                    Picker("表示位置", selection: $settings.zoomPosition) {
                        ForEach(AppSettings.ZoomPosition.allCases, id: \.self) { pos in
                            Text(pos.label).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
