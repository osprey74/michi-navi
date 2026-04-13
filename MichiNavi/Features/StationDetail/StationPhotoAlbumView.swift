import SwiftUI
import PhotosUI

/// フォトアルバム View — 3 枚タイルグリッド
///
/// - 空タイルをタップ: PhotosPicker で写真を選択し保存
/// - 写真タイルをタップ: フルスクリーン表示（左右スワイプ対応）
/// - 写真タイルを長押し: 削除確認アラート
/// - albumId: 道の駅は `station.id`、カントリーサインは `"sign_\(sign.id)"`
struct StationPhotoAlbumView: View {

    let albumId: String

    @Environment(StationPhotoStore.self) private var store
    @State private var photos: [UIImage?] = [nil, nil, nil]
    @State private var addingSlot: Int? = nil
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var fullscreenSelection: FullscreenSelection? = nil
    @State private var deletingSlot: Int? = nil
    @State private var showDeleteAlert = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { slot in
                photoTile(slot: slot)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear { reload() }
        // iCloud コンテナ URL が解決されたときに写真を再読み込み
        .onChange(of: store.baseURL) { reload() }
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: pickerItem) { _, item in
            guard let item, let slot = addingSlot else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    try? store.savePhoto(image, at: slot, for: albumId)
                    reload()
                }
                pickerItem = nil
                addingSlot = nil
            }
        }
        .fullScreenCover(item: $fullscreenSelection) { sel in
            PhotoFullscreenView(
                photos: photos.compactMap { $0 },
                initialIndex: filledIndex(for: sel.id)
            )
        }
        .alert("この写真を削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                if let slot = deletingSlot {
                    store.deletePhoto(at: slot, for: albumId)
                    reload()
                }
                deletingSlot = nil
            }
            Button("キャンセル", role: .cancel) { deletingSlot = nil }
        }
    }

    // MARK: - Tile

    @ViewBuilder
    private func photoTile(slot: Int) -> some View {
        if let image = photos[slot] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    fullscreenSelection = FullscreenSelection(id: slot)
                }
                .onLongPressGesture {
                    deletingSlot = slot
                    showDeleteAlert = true
                }
        } else {
            Button {
                addingSlot = slot
                showPicker = true
            } label: {
                ZStack {
                    Color(.systemFill)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func reload() {
        photos = store.loadPhotos(for: albumId)
    }

    /// 指定スロットが、compactMap した写真配列の何番目に対応するかを返す
    private func filledIndex(for slot: Int) -> Int {
        var count = 0
        for i in 0..<slot {
            if photos[i] != nil { count += 1 }
        }
        return count
    }
}

// MARK: - FullscreenSelection

private struct FullscreenSelection: Identifiable {
    let id: Int  // slot index
}

// MARK: - PhotoFullscreenView

/// フルスクリーン写真ビューア（左右スワイプでページ切り替え）
struct PhotoFullscreenView: View {

    let photos: [UIImage]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(photos: [UIImage], initialIndex: Int) {
        self.photos = photos
        self._currentIndex = State(initialValue: max(0, min(initialIndex, photos.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            // 閉じるボタン
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding()
            }
        }
    }
}
