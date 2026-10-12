# Release Notes — v2.2.0 (build 8)

---

## English

### ✨ New Features

- **iPhone Duo support**: Michi-Navi now adapts to both the outer and inner displays of iPhone Duo.
  - Toolbar buttons (Close, Done, Random Card) now include both an icon and a title, so they fit into the vertical bar on the side of the display and appear correctly in the overflow menu.
  - The map fills the entire display, including the area under the vertical status bar.
  - The navigation app picker now appears anchored to the navigation button on wider displays.

### 🐛 Bug Fixes

- **Fullscreen photo viewer**: Fixed an issue where the neighboring photo partially showed on screen when the safe area was asymmetric (e.g. with the vertical status bar on iPhone Duo).

### 📝 Documentation

- Added an iOS user guide (English / Japanese).
- Added App Store screenshots for iPhone Duo (outer and inner displays).

### 🔧 Maintenance

- Built with Xcode 27.1 (iOS 27.1 SDK). Moved Info.plist keys to build settings (no value changes).

---

## 日本語

### ✨ 新機能

- **iPhone Duo 対応**: iPhone Duo の外側・内側の両ディスプレイに対応しました。
  - ツールバーのボタン（閉じる・完了・ランダムカード）をアイコンとタイトル付きにし、画面横の縦配置バーやオーバーフローメニューに正しく表示されるようにしました。
  - 地図が縦配置ステータスバーの下まで画面全体に表示されるようになりました。
  - 幅の広い画面では、ナビアプリの選択肢がナビボタンを起点に表示されるようになりました。

### 🐛 バグ修正

- **全画面写真ビューア**: セーフエリアが左右非対称のとき（iPhone Duo の縦配置ステータスバーなど）に、隣の写真がはみ出して表示される問題を修正しました。

### 📝 ドキュメント

- iOS ユーザーガイド（英語・日本語）を追加しました。
- iPhone Duo 用の App Store スクリーンショット（外側・内側ディスプレイ）を追加しました。

### 🔧 メンテナンス

- Xcode 27.1（iOS 27.1 SDK）でのビルドに移行し、Info.plist のキーをビルド設定へ移しました（値の変更なし）。
