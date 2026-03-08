# Michi-navi 作業ログ

## セッション1: 大型機能追加（全8ステップ）— 全完了

### Step 1: AppSettings + SettingsView
- **新規作成**: `Shared/Models/AppSettings.swift` — `@Observable`、`ZoomPosition` enum（left/right）、UserDefaults 永続化
- **新規作成**: `Features/Settings/SettingsView.swift` — セグメント Picker でズーム位置選択

### Step 2: NavigationService
- **新規作成**: `Shared/Services/NavigationService.swift` — Apple Maps 連携ナビ起動

### Step 3: AppDelegate/MichiNaviApp 配線
- `navigationService`, `appSettings` を AppDelegate に追加、MichiNaviApp で environment 注入

### Step 4: RoadsideStationService にグループ化メソッド追加
- `availablePrefectures`, `municipalities(in:)`, `stations(in:municipality:)` 追加

### Step 5: DestinationPickerView（3階層ナビゲーション）
- **新規作成**: `Features/Destination/DestinationPickerView.swift`
- 都道府県（地方ごとSection）→ 市町村 → 道の駅 → 詳細+ナビ開始

### Step 6: ContentView 大改修
- 設定ギアボタン、目的地ボタン、ズーム位置切替、詳細シートに閉じる/ナビボタン

### Step 7: CarPlay CPPointOfInterestTemplate 化
- CPGridTemplate → CPPointOfInterestTemplate に全面書き換え
- 地図+POIピン最大12件、リスト/情報バーボタン、ナビ開始ボタン

### Step 8: ビルド確認 — 成功

---

## セッション2: 詳細画面充実化 + 自動縮尺 + UI改善

### 道の駅詳細画面の充実化
- **変更**: `Shared/Models/RoadsideStation.swift`
  - `FeatureInfo` 構造体 + `featureMap` 辞書追加（施設設備に SF Symbol アイコンと日本語ラベル対応）
  - `featureInfos` computed property で features 配列を表示用に変換
- **新規作成**: `Features/StationDetail/StationDetailView.swift`
  - 共通の道の駅詳細ビュー（写真 AsyncImage + 施設アイコングリッド + 基本情報 + ナビボタン）
  - `init(station:nearby:)` で地図タップ/目的地ピッカーの両方で統一利用
- **変更**: `Features/Map/ContentView.swift` — StationDetailSheet を共通 StationDetailView に差し替え、featureLabel 削除
- **変更**: `Features/Destination/DestinationPickerView.swift` — StationPickerDetailView を共通 StationDetailView に差し替え、featureLabel 削除

### 速度連動の地図自動縮尺
- **変更**: `Features/Map/ContentView.swift`
  - 速度→縮尺マッピング: 停車 0.01° / 市街地 0.02° / 一般道 0.05° / 高速 0.1° / 高速巡航 0.2°
  - 30%以上の縮尺差でアニメーション付き自動調整
  - 手動ズーム時は30秒間自動調整を一時停止

### 地図の現在地追従
- **変更**: `Features/Map/ContentView.swift`
  - `onChange(of: driveState.currentLocation)` で移動中（> 5 km/h）に地図中心を自車位置に追従
  - `CLLocationCoordinate2D` に `@retroactive Equatable` 準拠追加

### CarPlay 走行中リスト制限
- **変更**: `CarPlay/CarPlaySceneDelegate.swift`
  - 走行中（速度 > 5 km/h）に道の駅リストボタンをタップすると「駐車中に利用できます」アラート表示
  - 駐車中のみリスト画面を表示

### UI改善
- 設定アイコンを右上から左上に移動（MapUserLocationButton との重なり解消）

### 実機テスト対応
- **変更**: `App/MichiNavi.entitlements`
  - `carplay-driving-task` と `weatherkit` エンタイトルメントを一時的にコメントアウト
  - Personal チーム（無料）での実機インストールを可能にした
  - Developer Program 加入後に復元すること
- iPhone 実機での動作確認完了

---

## ファイル一覧（全変更・新規）

| ファイル | 状態 |
|---------|------|
| `Shared/Models/AppSettings.swift` | 新規作成 |
| `Shared/Models/RoadsideStation.swift` | 変更（FeatureInfo追加） |
| `Shared/Services/NavigationService.swift` | 新規作成 |
| `Shared/Services/RoadsideStationService.swift` | 変更（グループ化メソッド） |
| `Features/Settings/SettingsView.swift` | 新規作成 |
| `Features/Destination/DestinationPickerView.swift` | 新規作成→変更（共通Detail化） |
| `Features/StationDetail/StationDetailView.swift` | 新規作成 |
| `Features/Map/ContentView.swift` | 変更（自動縮尺、追従、UI改善） |
| `CarPlay/CarPlaySceneDelegate.swift` | 変更（POI化、走行中リスト制限） |
| `App/AppDelegate.swift` | 変更（サービス追加） |
| `App/MichiNaviApp.swift` | 変更（environment追加） |
| `App/MichiNavi.entitlements` | 変更（一時無効化） |

---

## 技術メモ

- `CLLocationCoordinate2D` は `Equatable` 非準拠 → `@retroactive Equatable` で拡張
- `CPPointOfInterestTemplate` のピンにカスタムラベル表示は不可（システム制御）
- CarPlay Simulator ではピンタップ反応が鈍い（実機では正常動作）
- CarPlay Simulator の解像度変更: `defaults write com.apple.iphonesimulator CarPlayExtraOptions -bool YES`
- `AppDelegate.shared` は `init()` で設定（`didFinishLaunchingWithOptions` では CarPlay に間に合わない）
- Personal チームでは CarPlay Driving Task / WeatherKit エンタイトルメント非対応 → Developer Program 必須

---

## 道の駅データ更新方針

現在は `roadside_stations.json`（1,200件）をアプリにバンドル。
Phase 1 ではアプリ更新時に JSON 差し替えで対応。
将来的にはサーバーからの定期ダウンロードに移行予定。

---

## 次回の作業候補

- Developer Program 加入 → エンタイトルメント復元 → CarPlay 実機テスト
- WeatherKit 統合（天気情報の実データ取得）
- Live Activity / WidgetKit 実装
- App Store Connect 設定・審査提出準備
