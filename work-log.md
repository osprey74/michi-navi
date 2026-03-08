# Michi-navi 大型機能追加 — 作業ログ

## 実装計画（全8ステップ）— 全完了

### Step 1: AppSettings + SettingsView (完了)
- **新規作成**: `MichiNavi/Shared/Models/AppSettings.swift`
  - `@Observable` クラス、`ZoomPosition` enum（left/right）
  - UserDefaults 永続化（`didSet` で自動保存）
- **新規作成**: `MichiNavi/Features/Settings/SettingsView.swift`
  - `@Bindable` で AppSettings をバインド
  - セグメント Picker でズーム位置選択、完了ボタン

### Step 2: NavigationService (完了)
- **新規作成**: `MichiNavi/Shared/Services/NavigationService.swift`
  - `@Observable` クラス
  - `navigateInAppleMaps(to:)`: MKMapItem.openInMaps で Apple Maps 起動
  - `destination`: 現在のナビ先を保持
  - `clearDestination()`: 目的地クリア

### Step 3: AppDelegate/MichiNaviApp 配線 (完了)
- **変更**: `MichiNavi/App/AppDelegate.swift`
  - `navigationService`, `appSettings` プロパティ追加
- **変更**: `MichiNavi/App/MichiNaviApp.swift`
  - `.environment(appDelegate.navigationService)` 追加
  - `.environment(appDelegate.appSettings)` 追加

### Step 4: RoadsideStationService にグループ化メソッド追加 (完了)
- **変更**: `MichiNavi/Shared/Services/RoadsideStationService.swift`
- **追加内容**:
  - `prefectureOrder` — 標準47都道府県順の静的配列
  - `availablePrefectures` — データに存在する都道府県のみ返す（標準順）
  - `municipalities(in:)` — 指定都道府県の市町村リスト（重複排除・ソート済み）
  - `stations(in:municipality:)` — 市町村内の道の駅リスト（名前順）

### Step 5: DestinationPickerView（3階層ナビゲーション）(完了)
- **新規作成**: `MichiNavi/Features/Destination/DestinationPickerView.swift`
- **構成**:
  - `DestinationPickerView` — 都道府県リスト（地方ごとにSection、駅数表示）
  - `MunicipalityListView` — 市町村リスト（「すべて」+ 各市町村、駅数表示）
  - `StationPickerListView` — 道の駅リスト（名前・路線表示）
  - `StationPickerDetailView` — 道の駅詳細（施設情報 + 「この道の駅へナビ開始」ボタン）

### Step 6: ContentView 大改修 (完了)
- **変更**: `MichiNavi/Features/Map/ContentView.swift`
- **追加・変更内容**:
  1. `@Environment(AppSettings.self)` と `@Environment(NavigationService.self)` 追加
  2. 設定ギアボタン（右上） → SettingsView シート表示
  3. 目的地ボタン（ズームの反対側） → DestinationPickerView フルスクリーンカバー
  4. ズーム位置切替: `settings.zoomPosition` で左右動的レイアウト
  5. StationDetailSheet 改修:
     - toolbar に「閉じる」ボタン追加
     - 「この道の駅へナビ開始」ボタン追加（NavigationService 連携）
  6. StationListPanel: タップで詳細表示できるよう Button 化
  7. Preview に全 environment 追加

### Step 7: CarPlay CPPointOfInterestTemplate 化 (完了)
- **変更**: `MichiNavi/CarPlay/CarPlaySceneDelegate.swift`
- **変更内容**: CPGridTemplate ベース → CPPointOfInterestTemplate に全面書き換え
- **テンプレート階層**:
  ```
  Root: CPPointOfInterestTemplate（地図+道の駅ピン最大12件）
  ├── leadingBarButton: リスト → CPListTemplate（速度表示+道の駅一覧）
  ├── trailingBarButton: 情報 → CPInformationTemplate（速度/天気/気温）
  └── POI選択 → 詳細カード + 「ナビ開始」CPTextButton → Apple Maps起動
  ```
- **実装詳細**:
  - `CPPointOfInterestTemplateDelegate` 準拠
  - `didChangeMapRegion:` で地図移動時にPOI再検索・更新
  - 各 POI に `primaryButton`（ナビ開始）設定
  - Timer で5秒間隔の自動更新
  - リストテンプレートに速度セクション + 道の駅一覧セクション
  - 道の駅タップで Apple Maps ナビ起動

### Step 8: ビルド確認 (完了)
- BuildProject でビルド成功を確認
- iPhone / CarPlay Simulator で動作確認済み

---

## ファイル一覧（変更・新規）

| ファイル | 状態 | Step |
|---------|------|------|
| `Shared/Models/AppSettings.swift` | 新規作成 | 1 |
| `Features/Settings/SettingsView.swift` | 新規作成 | 1 |
| `Shared/Services/NavigationService.swift` | 新規作成 | 2 |
| `App/AppDelegate.swift` | 変更 | 3 |
| `App/MichiNaviApp.swift` | 変更 | 3 |
| `Shared/Services/RoadsideStationService.swift` | 変更 | 4 |
| `Features/Destination/DestinationPickerView.swift` | 新規作成 | 5 |
| `Features/Map/ContentView.swift` | 変更 | 6 |
| `CarPlay/CarPlaySceneDelegate.swift` | 変更 | 7 |

---

## 技術メモ

- `RoadsideStation.prefecture` と `municipality` は `String?`（Optional）— グループ化時に `compactMap` が必要
- CarPlay の Driving Task カテゴリはテンプレート階層最大2段
- `CPPointOfInterestTemplate` は最大12件のPOI表示
- `CPListItem.image` は初期化時にのみ設定可能（get-only property）
- `AppDelegate.shared` は `init()` で設定（`didFinishLaunchingWithOptions` では遅い）
- CarPlay から `AppDelegate.shared?.navigationService` でナビサービスにアクセス
- CarPlay Simulator のピンタップは実機と挙動が異なる場合あり
- CarPlay Simulator の解像度変更: `defaults write com.apple.iphonesimulator CarPlayExtraOptions -bool YES`

---

## 道の駅データ更新方針

現在は `roadside_stations.json`（1,200件）をアプリにバンドル。
Phase 1 ではアプリ更新時に JSON 差し替えで対応。
将来的にはサーバーからの定期ダウンロードに移行予定。
