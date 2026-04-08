import SwiftUI

/// カントリーサインリスト・お気に入り・踏破の3タブシート
struct CountrySignListsView: View {

    @Environment(CountrySignService.self) private var signService
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                AllSignsTab()
                    .tabItem {
                        Label("カントリーサイン", systemImage: "signpost.right.fill")
                    }

                FavoriteSignsTab()
                    .tabItem {
                        Label("お気に入り", systemImage: "heart.fill")
                    }

                VisitedSignsTab()
                    .tabItem {
                        Label("踏破", systemImage: "checkmark.seal.fill")
                    }
            }
            .navigationTitle("カントリーサイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tab 1: 全サイン（管内別）

private struct AllSignsTab: View {

    @Environment(CountrySignService.self) private var signService

    var body: some View {
        List {
            ForEach(signService.signsBySubprefecture, id: \.office) { group in
                Section(group.office) {
                    ForEach(group.signs) { sign in
                        NavigationLink {
                            CountrySignDetailView(sign: sign)
                        } label: {
                            CountrySignListRow(sign: sign)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Tab 2: お気に入り

private struct FavoriteSignsTab: View {

    @Environment(CountrySignService.self) private var signService
    @Environment(AppSettings.self) private var settings

    private var favoriteSigns: [CountrySign] {
        signService.allSigns
            .filter { settings.favoriteSignIds.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if favoriteSigns.isEmpty {
                ContentUnavailableView(
                    "お気に入りがありません",
                    systemImage: "heart.slash",
                    description: Text("カントリーサインの詳細画面からお気に入りに登録できます")
                )
            } else {
                List {
                    ForEach(favoriteSigns) { sign in
                        NavigationLink {
                            CountrySignDetailView(sign: sign)
                        } label: {
                            CountrySignListRow(sign: sign)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Tab 3: 踏破リスト

private struct VisitedSignsTab: View {

    @Environment(CountrySignService.self) private var signService
    @Environment(AppSettings.self) private var settings

    private var visitedSigns: [CountrySign] {
        signService.allSigns
            .filter { settings.visitedSignIds.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if visitedSigns.isEmpty {
                ContentUnavailableView(
                    "踏破記録がありません",
                    systemImage: "checkmark.seal",
                    description: Text("カントリーサインの詳細画面から踏破に登録できます")
                )
            } else {
                List {
                    ForEach(visitedSigns) { sign in
                        NavigationLink {
                            CountrySignDetailView(sign: sign)
                        } label: {
                            CountrySignListRow(sign: sign)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Row Component

struct CountrySignListRow: View {

    let sign: CountrySign

    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 10) {
            // サムネイル
            signThumbnail

            // テキスト
            VStack(alignment: .leading, spacing: 2) {
                Text(sign.name)
                    .font(.body)
                Text(sign.subprefectureOffice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // お気に入り / 踏破バッジ
            statusIcon
        }
    }

    @ViewBuilder
    private var signThumbnail: some View {
        if let imageName = sign.imageName, let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGroupedBackground))
                Image(systemName: "signpost.right")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        let isFav = settings.favoriteSignIds.contains(sign.id)
        let isVis = settings.visitedSignIds.contains(sign.id)

        if isFav && isVis {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.red)
        } else if isFav {
            Image(systemName: "heart.circle.fill")
                .foregroundStyle(.red)
        } else if isVis {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.blue)
        }
    }
}
