# Release Notes — v2.0.0

---

## English

### ✨ New Features

**Country Sign (カントリーサイン) — Hokkaido Municipality Stamps**

- Display all 179 Hokkaido municipality country sign markers on the map
- Show municipality boundary overlays (red dashed lines) when markers are enabled
- Country Sign detail screen: image, design origin, municipality info (population, area, flower), favorites & visited management
- Country Sign list screen with three tabs: All (grouped by subprefecture), Favorites, Visited
- **Random Card Draw**: Draw a random unvisited country sign in a card-style sheet, inspired by the TV show *Suiyō Dōdesho*
  - Shows visited progress: "踏破済み: X / 179" with a linear progress bar
  - Buttons: View on Map / Details / Draw Again
- **Navigate to Town Hall**: "Go to [Municipality]" button on the Country Sign detail screen, navigating to the municipal office coordinates
- Country sign marker ON/OFF toggle on the map

**OS Share Sheet (NaviTime & other navigation apps)**

- Share button added next to the navigation button on both Roadside Station and Country Sign detail screens
- Shares location as `MKMapItem` + Apple Maps URL, enabling apps without public URL schemes (e.g., NaviTime) to receive location via share extension

**Data**

- Added `officeCoordinate` (town hall / municipal office lat/lng) for all 179 Hokkaido municipalities
- Source: Hokkaido Development Bureau

### 🔧 Maintenance

- Unified button labels across Roadside Station and Country Sign detail screens: "お気に入り" / "踏破済み"
- Unified empty-state messages across all list views
- Terminology unified: "到達" → "踏破" throughout the app
- Added Country Sign image usage credits to Settings screen (北海道開発局, 大空町, 本別町, 今金町)

---

## 日本語

### ✨ 新機能

**カントリーサイン — 北海道市町村スタンプラリー**

- 北海道全179市町村のカントリーサインマーカーを地図に表示
- マーカーON時に市町村境界線オーバーレイ（赤点線）を表示
- カントリーサイン詳細画面: 画像・デザイン由来・市町村情報（人口・面積・市の花）・お気に入り/踏破管理
- カントリーサインリスト画面: すべて（振興局別）/ お気に入り / 踏破済み の3タブ
- **ランダムカードドロー**: 「水曜どうでしょう」風に未踏破カントリーサインを1枚ランダムで引くカード表示
  - 踏破進捗「踏破済み: X / 179」とリニアプログレスバーを表示
  - ボタン: 地図で見る / 詳細 / もう一度引く
- **役場へナビ**: カントリーサイン詳細画面に「（市町村名）へ行く」ボタンを追加。市役所・役場を目的地に設定
- 地図上のカントリーサインマーカーON/OFFトグル

**OS共有シート（NaviTime 等カスタムURL非公開ナビアプリ対応）**

- 道の駅・カントリーサイン詳細画面のナビボタン横に「共有」ボタンを追加
- `MKMapItem` + Apple Maps URLを渡すことでNaviTimeなど共有拡張経由でのナビに対応

**データ**

- 北海道全179市町村の役場座標（`officeCoordinate`）を追加
- 出典: 北海道開発局

### 🔧 メンテナンス

- 道の駅・カントリーサイン詳細画面のボタン文言を統一:「お気に入り」/「踏破済み」
- 全リスト画面の空状態メッセージを統一
- アプリ全体の表記を「到達」→「踏破」に統一
- 設定画面にカントリーサイン画像の利用許諾クレジットを追加（北海道開発局・大空町・本別町・今金町）
