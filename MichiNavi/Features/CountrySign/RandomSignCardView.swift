import SwiftUI

/// 水曜どうでしょう風・未踏破カントリーサインランダムドロービュー
struct RandomSignCardView: View {

    @Environment(CountrySignService.self) private var signService
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// CombinedListsView を閉じるためのコールバック
    var dismissParent: (() -> Void)?

    @State private var drawnSign: CountrySign?
    @State private var isAnimating = false

    private var unvisitedSigns: [CountrySign] {
        signService.allSigns.filter { !settings.visitedSignIds.contains($0.id) }
    }

    private var visitedCount: Int { settings.visitedSignIds.count }
    private var totalCount: Int { signService.allSigns.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 踏破進捗バー（常時表示）
                progressSection

                Group {
                    if unvisitedSigns.isEmpty {
                        // 全踏破達成
                        ContentUnavailableView {
                            Label("全市町村を踏破しました！", systemImage: "trophy.fill")
                        } description: {
                            Text("北海道179市町村のカントリーサインをすべて踏破しました。")
                        }
                    } else if let sign = drawnSign {
                        cardView(sign: sign)
                    } else {
                        // 初期状態（onAppear でドロー）
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("ランダムカード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear { drawCard() }
    }

    // MARK: - 踏破進捗バー

    private var progressSection: some View {
        VStack(spacing: 6) {
            Text("踏破済み: \(visitedCount) / \(totalCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(visitedCount), total: Double(max(totalCount, 1)))
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - カード表示

    @ViewBuilder
    private func cardView(sign: CountrySign) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // カード本体
                VStack(spacing: 0) {
                    // サイン画像
                    signImage(sign: sign)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()


                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 24)
                .scaleEffect(isAnimating ? 0.92 : 1.0)
                .opacity(isAnimating ? 0 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isAnimating)

                // アクションボタン群
                VStack(spacing: 12) {
                    // 地図で見る・詳細ボタン
                    HStack(spacing: 12) {
                        Button {
                            settings.mapFocusSign = sign
                            dismiss()
                            dismissParent?()
                        } label: {
                            Label("地図で見る", systemImage: "map.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        NavigationLink {
                            CountrySignDetailView(sign: sign)
                        } label: {
                            Label("詳細", systemImage: "info.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }

                    // もう一度引くボタン
                    Button {
                        drawCard()
                    } label: {
                        Label("もう一度引く", systemImage: "square.stack")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - サイン画像

    @ViewBuilder
    private func signImage(sign: CountrySign) -> some View {
        if let imageName = sign.imageName,
           let path = Bundle.main.path(forResource: imageName, ofType: "jpg"),
           let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Color(.systemGroupedBackground)
                Image(systemName: "signpost.right")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - ランダム選択

    private func drawCard() {
        guard let newSign = unvisitedSigns.randomElement() else { return }

        if drawnSign != nil {
            // アニメーション付きで切り替え
            withAnimation { isAnimating = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                drawnSign = newSign
                withAnimation { isAnimating = false }
            }
        } else {
            drawnSign = newSign
        }
    }
}
