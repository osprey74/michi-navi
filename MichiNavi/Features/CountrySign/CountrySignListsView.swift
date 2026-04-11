import SwiftUI

/// カントリーサインリスト・お気に入り・踏破の3タブシート
struct CountrySignListsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CountrySignListsContent()
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

/// 統合リストビューから再利用可能なカントリーサインタブコンテンツ
struct CountrySignListsContent: View {
    var body: some View {
        TabView {
            AllSignsTab()
                .tabItem { Label("カントリーサイン", systemImage: "signpost.right.fill") }
            FavoriteSignsTab()
                .tabItem { Label("お気に入り", systemImage: "heart.fill") }
            VisitedSignsTab()
                .tabItem { Label("踏破済み", systemImage: "checkmark.seal.fill") }
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
                ContentUnavailableView {
                    Label("お気に入りなし", systemImage: "heart")
                } description: {
                    Text("詳細画面でハートボタンをタップすると追加されます")
                }
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
                ContentUnavailableView {
                    Label("踏破記録なし", systemImage: "checkmark.seal")
                } description: {
                    Text("詳細画面でチェックボタンをタップすると追加されます")
                }
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
        if let imageName = sign.imageName,
           let path = Bundle.main.path(forResource: imageName, ofType: "jpg"),
           let uiImage = UIImage(contentsOfFile: path) {
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
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.blue)
        }
    }
}
