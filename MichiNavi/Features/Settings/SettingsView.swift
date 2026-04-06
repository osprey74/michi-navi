import SwiftUI

/// 設定画面
struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showAPIKeyField = false
    @State private var apiKeyInput = ""
    @State private var showAPIKey = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                mapTileSection(settings: settings)
                googleMapsSection(settings: settings)
                creditSection
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

    // MARK: - 地図タイル

    private func mapTileSection(settings: AppSettings) -> some View {
        Section("地図タイル") {
            // API キー未登録の場合 Google Maps を除いて表示
            let tiles = MapTileType.allCases.filter { tile in
                tile != .googleMaps || settings.hasGoogleMapsAPIKey
            }
            @Bindable var s = settings
            Picker("地図タイル", selection: $s.selectedMapTile) {
                ForEach(tiles, id: \.self) { tile in
                    Text(tile.label).tag(tile)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    // MARK: - Google Maps API キー

    @ViewBuilder
    private func googleMapsSection(settings: AppSettings) -> some View {
        Section {
            // 注意書き
            Text("""
            Google Maps の地図タイルを利用する場合に設定してください。APIキーを登録すると「地図タイル」にGoogle Mapsが追加されます。Map Tiles API を有効にしたキーが必要です。

            これは高度な設定であり、サポート対象外です。APIキーの登録・管理はすべて自己責任で行ってください。
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)

            if settings.hasGoogleMapsAPIKey {
                // 登録済み: マスク表示 + 削除ボタン
                HStack {
                    if showAPIKey {
                        Text(settings.googleMapsAPIKey)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Text(maskedAPIKey(settings.googleMapsAPIKey))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    settings.googleMapsAPIKey = ""
                    // Google Maps 選択中なら別タイルに切替
                    if settings.selectedMapTile == .googleMaps {
                        settings.selectedMapTile = .gsiPale
                    }
                } label: {
                    Label("APIキーを削除", systemImage: "trash")
                }
            } else {
                // 未登録: 入力フィールドを展開
                if showAPIKeyField {
                    HStack {
                        if showAPIKey {
                            TextField("APIキーを入力", text: $apiKeyInput)
                                .font(.system(.footnote, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("APIキーを入力", text: $apiKeyInput)
                                .font(.system(.footnote, design: .monospaced))
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("登録する") {
                        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return }
                        settings.googleMapsAPIKey = key
                        apiKeyInput = ""
                        showAPIKeyField = false
                        showAPIKey = false
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button("APIキーを登録") {
                        showAPIKeyField = true
                    }
                }
            }
        } header: {
            Text("Google Maps API キー")
        }
    }

    // MARK: - クレジット

    private var creditSection: some View {
        Section("クレジット") {
            // アプリバージョン・著作権
            HStack {
                Text("Michi-Navi")
                    .font(.footnote)
                Spacer()
                Text("v\(appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("COPYRIGHT 2026 osprey74")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // 道の駅データ出典
            VStack(alignment: .leading, spacing: 4) {
                Text("道の駅データ出典")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("一般社団法人 全国道の駅連絡会")
                    .font(.footnote)
                Link("http://www.michi-no-eki.jp/", destination: URL(string: "http://www.michi-no-eki.jp/")!)
                    .font(.footnote)
            }
            .padding(.vertical, 2)

            // アイコン
            Link(destination: URL(string: "https://www.flaticon.com/free-icons/navigation")!) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                    Text("Navigation icons by ChilliColor - Flaticon")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Helper

    private func maskedAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "●", count: key.count) }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
}
