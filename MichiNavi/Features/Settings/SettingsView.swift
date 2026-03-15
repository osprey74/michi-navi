import SwiftUI

/// 設定画面
struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
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
                    Toggle(isOn: $settings.showRVParks) {
                        Label("RVパーク・キャンプ場", systemImage: "tent.fill")
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
