# Michi-navi Phase 0 — Xcode セットアップ手順

> **対象**: Xcode 26.3 / Apple Silicon Mac
> **所要時間**: 約 30〜45 分
> **完了条件**: CarPlay Simulator に "Michi-navi" が表示され、メインメニューが操作できる

---

## Step 1: Xcode プロジェクト新規作成

1. Xcode を起動 → **Create New Project**
2. **iOS → App** を選択
3. 以下の設定で作成：

| 項目 | 値 |
|------|----|
| Product Name | `MichiNavi` |
| Team | （Apple Developer アカウント） |
| Organization Identifier | `com.osprey74` |
| Bundle Identifier | `com.osprey74.michi-navi` |
| Interface | SwiftUI |
| Language | Swift |
| Include Tests | ✅ |

4. **保存先**: リポジトリルート（`michi-navi/`）を選択

---

## Step 2: ソースファイルの配置

クローンしたファイルを Xcode プロジェクトに追加します。

```
michi-navi/
├── CLAUDE.md               ← そのまま配置（Xcode に追加不要）
├── README.md               ← そのまま配置
├── docs/
│   └── michi-navi-requirements.docx
└── MichiNavi/
    ├── App/
    │   ├── MichiNaviApp.swift      ← 自動生成ファイルを差し替え
    │   ├── AppDelegate.swift       ← 追加
    │   ├── MichiNavi.entitlements  ← 追加
    │   └── Info.plist              ← 既存を参照して設定追加
    ├── Features/Map/
    │   └── ContentView.swift       ← 自動生成を差し替え
    ├── CarPlay/
    │   └── CarPlaySceneDelegate.swift  ← 追加
    └── Shared/
        ├── Models/
        │   └── DriveState.swift    ← 追加
        └── Services/
            └── LocationService.swift   ← 追加
```

**Xcode への追加方法**:
- Project Navigator で対象グループを右クリック → "Add Files to MichiNavi"
- または、ファイルをドラッグ＆ドロップ

---

## Step 3: CarPlay Extension ターゲット追加

1. Xcode → File → **New → Target**
2. **iOS → CarPlay Scene Template** を選択
3. 設定：

| 項目 | 値 |
|------|----|
| Product Name | `MichiNaviCarPlay` |
| Bundle Identifier | `com.osprey74.michi-navi.carplay` |

4. `MichiNaviCarPlay/CarPlayTemplateManager.swift` に最小実装を追加

---

## Step 4: Widget Extension ターゲット追加

1. Xcode → File → **New → Target**
2. **iOS → Widget Extension** を選択
3. 設定：

| 項目 | 値 |
|------|----|
| Product Name | `MichiNaviWidget` |
| Bundle Identifier | `com.osprey74.michi-navi.widget` |
| Include Live Activity | ✅ |
| Include Configuration App Intent | ❌（不要） |

---

## Step 5: App Group の設定（全ターゲット共通）

全ターゲット（MichiNavi / MichiNaviCarPlay / MichiNaviWidget）で実施：

1. ターゲット選択 → **Signing & Capabilities** タブ
2. **+ Capability** → "App Groups" を追加
3. `+` ボタン → `group.com.osprey74.michi-navi` を追加

---

## Step 6: Capabilities の設定（MichiNavi メインのみ）

**Signing & Capabilities** → **+ Capability** で以下を追加：

- ✅ **Background Modes** → "Location updates" と "Audio, AirPlay, and Picture in Picture" にチェック
- ✅ **WeatherKit**
- ✅ **CarPlay**（エンタイトルメント取得後に追加。申請前は `.entitlements` に手動記述でテスト可）

---

## Step 7: Info.plist の更新

`MichiNavi/App/Info.plist` に以下のキーを追加（`Info.plist` ファイルの内容を参照）：

- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `UIBackgroundModes: [location, audio]`
- `UIApplicationSceneManifest`（CarPlay Scene の登録）

---

## Step 8: CarPlay Simulator のインストール

1. Xcode メニュー → **Xcode → Open Developer Tool → More Developer Tools...**
2. Apple Developer サイトの "Additional Tools for Xcode 26" をダウンロード
3. `Hardware` フォルダ内の `CarPlay Simulator.app` を `/Applications` にコピー

---

## Step 9: 動作確認

```
1. Xcode で iPhone Simulator（iOS 17+）を選択してビルド・実行
2. CarPlay Simulator を起動
3. CarPlay Simulator → Connect → シミュレータを選択
4. CarPlay 画面に "Michi-navi" アイコンが表示されることを確認
5. タップして「目的地設定 / 周辺を検索 / ドライブ情報」のグリッドが表示されればOK
```

---

## Phase 0 完了チェックリスト

- [ ] `MichiNavi` ターゲットがビルド成功する
- [ ] iPhone Simulator でマップ画面が表示される
- [ ] CarPlay Simulator に Michi-navi アイコンが表示される
- [ ] CPGridTemplate（3ボタン）が正常表示される
- [ ] 各ボタンをタップして次画面（CPListTemplate / CPInformationTemplate）に遷移できる
- [ ] GitHub に初回コミットを push する（`chore: Phase 0 initial setup`）

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| CarPlay Simulator に何も表示されない | Scene Manifest の設定漏れ | Info.plist の `CPTemplateApplicationSceneSessionRoleApplication` を確認 |
| ビルドエラー `Cannot find type 'CarPlaySceneDelegate'` | CarPlay フレームワーク未リンク | Build Phases → Link Binary With Libraries → `CarPlay.framework` を追加 |
| 位置情報が取得できない | エンタイトルメントまたは Info.plist の設定漏れ | NSLocationAlwaysAndWhenInUse... キーを確認 |
| App Group でデータ共有できない | App Group ID の不一致 | 全ターゲットで `group.com.osprey74.michi-navi` を統一 |
