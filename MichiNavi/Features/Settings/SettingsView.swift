import SwiftUI

/// 設定画面
struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
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
