# Release Notes — v2.1.0 (build 4)

---

## English

### ✨ New Features

**iCloud Sync**

- Favorites and visited data (roadside stations & country signs) now sync across devices via iCloud Key-Value Store
  - Data migrates automatically from local storage on first launch
  - Changes from other devices are applied when the app comes to the foreground
- Photo albums now sync via iCloud Drive (ubiquity container `iCloud.com.osprey74.michi-navi`)
  - Existing local photos are migrated to iCloud automatically
  - Files not yet downloaded show a placeholder and trigger background download

**Country Sign Photo Album**

- Added "Photo Album" section to the Country Sign detail screen
- Same design as the roadside station album: 3-slot tile grid, full-screen viewer, long-press to delete
- Album data stored under `sign_{municipalityCode}` to avoid collision with station IDs

### 🐛 Bug Fixes / Style

**Visited icon unified to `checkmark.shield.fill` everywhere**

- Country Sign list row (was `checkmark.seal.fill`)
- Country Sign map badge (was `checkmark.seal.fill`)
- Visited tab icon in both roadside station and country sign list screens (was `checkmark.seal.fill`)
- Empty-state icon in visited tabs (was `checkmark.seal`)

---

## 日本語

### ✨ 新機能

**iCloud 同期**

- お気に入り・踏破データ（道の駅・カントリーサイン）が iCloud Key-Value Store で端末間同期されます
  - 初回起動時にローカルデータを自動移行
  - フォアグラウンド復帰時に他端末の変更を取り込み
- フォトアルバムが iCloud Drive（コンテナ `iCloud.com.osprey74.michi-navi`）で同期されます
  - 既存のローカル写真を自動で iCloud へ移行
  - 未ダウンロードファイルはプレースホルダー表示＋バックグラウンドDLをトリガー

**カントリーサイン フォトアルバム**

- カントリーサイン詳細画面に「フォトアルバム」セクションを追加
- 道の駅と同仕様: 3 枠タイルグリッド・フルスクリーンビューア・長押し削除
- アルバム ID は `sign_{市町村コード}` で道の駅 ID との衝突を回避

### 🐛 バグ修正 / スタイル

**踏破済みアイコンを `checkmark.shield.fill` に全面統一**

- カントリーサインリスト行（`checkmark.seal.fill` から変更）
- カントリーサイン地図バッジ（同上）
- 道の駅・カントリーサインリストの踏破タブアイコン（同上）
- 踏破タブの空状態アイコン（`checkmark.seal` から変更）
