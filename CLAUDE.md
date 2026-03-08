# Michi-navi — Claude Code 引き継ぎドキュメント

## プロジェクト概要

**Michi-navi（道ナビ）** は Apple CarPlay 対応の iPhone ドライビングタスクアプリです。
走行中に最小限のタッチ操作でドライブ補助情報（気象・周辺 POI・速度・到着予定）を提供します。

- **リポジトリ**: https://github.com/osprey74/michi-navi
- **ライセンス**: MIT
- **開発者**: Sohshi / osprey74
- **Phase 1 目標**: CarPlay Driving Task エンタイトルメント取得 → App Store 公開

---

## 技術スタック

| レイヤー | 採用技術 | バージョン |
|---------|---------|----------|
| 言語 | Swift | 6.x |
| UI（iPhone） | SwiftUI | iOS 17+ |
| UI（CarPlay） | CarPlay Framework | iOS 17+ |
| 地図 | MapKit | iOS 17+ |
| 位置情報 | CoreLocation | iOS 17+ |
| 気象 | WeatherKit | iOS 17+ |
| 動的表示 | ActivityKit (Live Activity) | iOS 16.2+ |
| ウィジェット | WidgetKit | iOS 17+ |
| データ永続化 | SwiftData + UserDefaults | iOS 17+ |
| 並行処理 | Swift Concurrency (async/await) | Swift 6 |

---

## ディレクトリ構成

```
michi-navi/
├── CLAUDE.md                       ← このファイル
├── README.md
├── .github/
│   └── workflows/
│       └── release.yml             ← GitHub Actions リリースワークフロー
├── MichiNavi/                      ← メイン iOS アプリ
│   ├── App/
│   │   ├── MichiNaviApp.swift      ← @main エントリポイント
│   │   └── AppDelegate.swift       ← UIApplicationDelegate（CarPlay Scene 登録）
│   ├── Features/
│   │   ├── Map/
│   │   │   └── MapView.swift       ← 現在地マップ（MapKit）
│   │   ├── Route/
│   │   │   └── RouteView.swift     ← ルート検索 UI
│   │   ├── POI/
│   │   │   └── POIListView.swift   ← 周辺施設一覧
│   │   └── Weather/
│   │       └── WeatherView.swift   ← 気象情報表示
│   ├── CarPlay/
│   │   └── CarPlaySceneDelegate.swift  ← CPTemplateApplicationSceneDelegate
│   └── Shared/
│       ├── Models/
│       │   ├── DriveState.swift    ← 走行状態（速度・位置）
│       │   ├── RouteInfo.swift     ← ルート情報
│       │   └── POIItem.swift       ← POI データ
│       └── Services/
│           ├── LocationService.swift   ← CoreLocation ラッパー
│           ├── RouteService.swift      ← MapKit ルート検索
│           └── WeatherService.swift    ← WeatherKit ラッパー
├── MichiNaviCarPlay/               ← CarPlay Extension（別ターゲット）
│   └── CarPlayTemplateManager.swift
├── MichiNaviWidget/                ← Widget Extension
│   └── MichiNaviWidget.swift
├── MichiNaviActivity/              ← Live Activity
│   └── DriveActivityAttributes.swift
├── MichiNavi.xcodeproj/
└── MichiNavi.xcworkspace/
```

---

## Xcode ターゲット構成

| ターゲット | Bundle ID | 役割 |
|-----------|-----------|------|
| MichiNavi | com.osprey74.michi-navi | メイン iOS アプリ |
| MichiNaviCarPlay | com.osprey74.michi-navi.carplay | CarPlay Extension |
| MichiNaviWidget | com.osprey74.michi-navi.widget | WidgetKit |
| MichiNaviActivity | com.osprey74.michi-navi.activity | Live Activity |

**App Group**: `group.com.osprey74.michi-navi`（全ターゲットで共有）

---

## CarPlay 設計原則（必須遵守）

1. **テンプレートのみ使用** — カスタム UIView は CarPlay 画面に表示不可
2. **テキスト入力禁止** — 走行中のキーボード入力は Apple ガイドライン違反
3. **タップ 2 回以内** — 全操作を 2 タップ以内で完結させる
4. **テンプレート階層は最大 2 段** — Driving Task カテゴリの制限
5. **iPhone ロック中も動作すること** — バックグラウンド動作を必ずテスト

### 使用するテンプレート

| テンプレート | 用途 |
|------------|------|
| `CPGridTemplate` | メインメニュー（目的地設定 / 周辺検索 / ドライブ情報） |
| `CPListTemplate` | POI 一覧 / 目的地履歴 |
| `CPInformationTemplate` | ドライブ情報詳細（気象・速度） |
| `CPAlertTemplate` | 到着通知 / 気象警報 |

---

## エンタイトルメント

### MichiNavi.entitlements（メインアプリ）
```xml
<key>com.apple.developer.carplay-driving-task</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.osprey74.michi-navi</string>
</array>
<key>com.apple.developer.weatherkit</key>
<true/>
```

### Info.plist 必須キー
```
NSLocationAlwaysAndWhenInUseUsageDescription
NSLocationWhenInUseUsageDescription
UIBackgroundModes: [location]
```

---

## 現在のフェーズと未対応タスク

### ✅ 完了
- 要件定義書作成（docs/michi-navi-requirements.docx）
- CLAUDE.md 作成（このファイル）
- ディレクトリ構成定義

### 🔲 Phase 0（次のタスク）
- [ ] Xcode プロジェクト新規作成（iOS App テンプレート）
- [ ] CarPlay Extension ターゲット追加
- [ ] Widget Extension ターゲット追加
- [ ] App Group 設定
- [ ] CarPlay Simulator 接続確認
- [ ] Hello CarPlay（CPGridTemplate 表示）動作確認

### 🔲 Phase 1-A
- [ ] CoreLocation セットアップ（常時許可）
- [ ] MapKit 現在地表示
- [ ] 速度・方位リアルタイム表示
- [ ] DriveState モデル実装

### 🔲 Phase 1-B
- [ ] CarPlaySceneDelegate 実装
- [ ] CPGridTemplate メインメニュー
- [ ] CPListTemplate POI 一覧
- [ ] MapKit POI 検索

### 🔲 Phase 1-C
- [ ] WeatherKit 統合
- [ ] Live Activity（ActivityKit）
- [ ] WidgetKit（systemSmall）

### 🔲 Phase 1-D
- [ ] App Store Connect 設定
- [ ] エンタイトルメント申請
- [ ] TestFlight 配布
- [ ] App Store 審査提出

---

## コーディング規約

- **命名**: Swift API Design Guidelines 準拠（lowerCamelCase）
- **アーキテクチャ**: MVVM + SwiftUI `@Observable`
- **非同期処理**: `async/await`（Combine は使用しない）
- **エラーハンドリング**: `Result` 型または `throws`
- **コメント**: 公開 API は `/// DocComment`
- **テスト**: XCTest（Unit Test）。UI テストは Xcode Simulator で手動確認

---

## 参考リンク

- CarPlay 開発者ページ: https://developer.apple.com/carplay/
- CarPlay Developer Guide (2026-02): https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf
- CarPlay API ドキュメント: https://developer.apple.com/documentation/carplay/
- WeatherKit: https://developer.apple.com/documentation/weatherkit
- ActivityKit: https://developer.apple.com/documentation/activitykit
- WWDC25 CarPlay セッション: https://developer.apple.com/videos/play/wwdc2025/216/
