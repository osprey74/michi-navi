import SwiftUI

/// カントリーサイン詳細画面
struct CountrySignDetailView: View {

    let sign: CountrySign

    @Environment(AppSettings.self) private var settings
    @Environment(NavigationService.self) private var navigationService

    @State private var showNavAppPicker = false
    @State private var showShareSheet = false

    var body: some View {
        @Bindable var settings = settings

        List {
            // MARK: カントリーサイン画像
            Section {
                signImage
                    .listRowInsets(EdgeInsets())
            }

            // MARK: お気に入り / 踏破ボタン
            Section {
                HStack(spacing: 12) {
                    let isFav = settings.favoriteSignIds.contains(sign.id)
                    Button {
                        settings.toggleSignFavorite(sign.id)
                    } label: {
                        Label(
                            isFav ? "お気に入り済み" : "お気に入り",
                            systemImage: isFav ? "heart.fill" : "heart"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isFav ? .red : .secondary)

                    let isVis = settings.visitedSignIds.contains(sign.id)
                    Button {
                        settings.toggleSignVisited(sign.id)
                    } label: {
                        Label(
                            isVis ? "踏破済み" : "踏破に登録",
                            systemImage: isVis ? "checkmark.seal.fill" : "checkmark.seal"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isVis ? .blue : .secondary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: カントリーサイン情報
            Section("カントリーサインについて") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sign.name)
                        .font(.title2.bold())
                    Text(sign.nameKana)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                if let desc = sign.designDescription, !desc.isEmpty {
                    LabeledContent("デザイン", value: desc)
                }

                if let origin = sign.originText, !origin.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("由来")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(origin)
                            .font(.body)
                    }
                }
            }

            // MARK: 市町村情報
            Section("市町村情報") {
                LabeledContent("管内", value: sign.subprefectureOffice)
                LabeledContent("種別", value: sign.municipalityType)
                if let pop = sign.population, let year = sign.populationYear {
                    LabeledContent("人口") {
                        Text("\(pop.formatted()) 人（\(year)年）")
                    }
                }
                if let area = sign.areaSqKm {
                    LabeledContent("面積", value: String(format: "%.2f km²", area))
                }
            }

            // MARK: 市の花
            if let flower = sign.flower {
                Section("市町村の花") {
                    HStack(spacing: 10) {
                        if let hex = flower.colorHex, let color = Color(hex: hex) {
                            Circle()
                                .fill(color)
                                .frame(width: 20, height: 20)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(flower.name)
                                .font(.headline)
                            if let desc = flower.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // MARK: 役場へナビ / 共有
            if let coord = sign.officeCoordinate {
                Section {
                    HStack(spacing: 8) {
                        Button {
                            showNavAppPicker = true
                        } label: {
                            Label("\(sign.name)へ行く", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .sheet(isPresented: $showShareSheet) {
                    LocationShareSheet(coordinate: coord, name: sign.name)
                }
            }

            // MARK: 公式サイトリンク
            Section {
                if let urlStr = sign.tourismUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label(sign.tourismSiteName ?? "公式サイトを開く", systemImage: "safari")
                    }
                } else if let query = "\(sign.name) 公式サイト"
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                    let searchURL = URL(string: "https://www.google.com/search?q=\(query)") {
                    Link(destination: searchURL) {
                        Label("\(sign.name) を検索", systemImage: "magnifyingglass")
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("公式サイト")
            }
        }
        .navigationTitle(sign.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { settings.mapFocusSign = sign }
        .confirmationDialog("ナビアプリを選択", isPresented: $showNavAppPicker) {
            if let coord = sign.officeCoordinate {
                ForEach(navigationService.availableApps()) { app in
                    Button(app.displayName) {
                        navigationService.navigate(to: coord, name: sign.name, with: app)
                    }
                }
            }
        }
    }

    // MARK: - Sign Image

    @ViewBuilder
    private var signImage: some View {
        Group {
            if let imageName = sign.imageName,
               let path = Bundle.main.path(forResource: imageName, ofType: "jpg"),
               let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color(.systemGroupedBackground))
            } else {
                ZStack {
                    Color(.systemGroupedBackground)
                    VStack(spacing: 8) {
                        Image(systemName: "signpost.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("画像準備中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            }
        }
    }
}

// MARK: - Color hex initializer

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6,
              let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
