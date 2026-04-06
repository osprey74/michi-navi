# Michi-navi — Claude Code 引き継ぎドキュメント

## プロジェクト概要

**Michi-navi（道ナビ）** は北海道の道の駅・カントリーサインを巡る iPhone ドライビングコンパニオンアプリです。
現在地周辺の道の駅一覧、施設詳細、フォトアルバム、カントリーサイン情報などを提供します。

- **リポジトリ**: https://github.com/osprey74/michi-navi
- **ライセンス**: MIT
- **開発者**: Sohshi / osprey74
- **Phase 1 目標**: App Store 公開（日本国内限定）

---

## 技術スタック

| レイヤー | 採用技術 | バージョン |
|---------|---------|----------|
| 言語 | Swift | 6.x |
| UI | SwiftUI | iOS 17+ |
| 地図 | MapKit | iOS 17+ |
| 位置情報 | CoreLocation | iOS 17+ |
| 気象 | WeatherKit | iOS 17+ |
| データ永続化 | UserDefaults | iOS 17+ |
| 並行処理 | Swift Concurrency (async/await) | Swift 6 |

---

## ディレクトリ構成

```
michi-navi/
├── CLAUDE.md                       ← このファイル
├── README.md
├── docs/
│   └── privacy.html                ← GitHub Pages プライバシーポリシー
├── .github/
│   └── workflows/
│       └── release.yml             ← GitHub Actions リリースワークフロー
└── MichiNavi/                      ← メイン iOS アプリ
    ├── App/
    │   ├── MichiNaviApp.swift      ← @main エントリポイント
    │   ├── AppDelegate.swift       ← UIApplicationDelegate
    │   └── MichiNavi.entitlements  ← エンタイトルメント（WeatherKit 等）
    ├── Features/
    │   ├── Map/
    │   │   ├── ContentView.swift   ← メイン画面
    │   │   └── CustomMapView.swift ← MapKit ラッパー
    │   ├── Settings/
    │   │   └── SettingsView.swift  ← 設定・クレジット
    │   ├── Destination/
    │   │   └── DestinationPickerView.swift
    │   ├── StationDetail/
    │   │   ├── StationDetailView.swift   ← 道の駅詳細
    │   │   └── StationPhotoAlbumView.swift ← フォトアルバム（3枚）
    │   └── StationList/
    │       └── StationListsView.swift    ← 道の駅リスト
    ├── Shared/
    │   ├── Models/
    │   │   ├── DriveState.swift    ← 走行状態（速度・位置・気象）
    │   │   ├── RoadsideStation.swift ← 道の駅モデル
    │   │   ├── AppSettings.swift   ← お気に入り・訪問済み
    │   │   └── MapTileType.swift
    │   └── Services/
    │       ├── LocationService.swift   ← CoreLocation ラッパー
    │       ├── RoadsideStationService.swift ← 道の駅データ管理
    │       ├── NavigationService.swift ← 外部ナビアプリ連携
    │       ├── StationPhotoStore.swift ← 写真保存・管理
    │       ├── GeoUtils.swift          ← 地理計算ユーティリティ
    │       └── GoogleMapsTileOverlay.swift
    └── MichiNavi/
        ├── Resources/
        │   ├── roadside_stations.json          ← 全国道の駅データ
        │   ├── hokkaido_country_signs.json     ← 北海道カントリーサイン（179件）
        │   ├── hokkaido_municipalities.json
        │   ├── hokkaido_boundaries_simplified.geojson
        │   └── municipality_centroids_verified.json
        ├── Assets.xcassets
        └── Info.plist
```

---

## Xcode ターゲット構成

| ターゲット | Bundle ID | 役割 |
|-----------|-----------|------|
| MichiNavi | com.osprey74.michi-navi | メイン iOS アプリ（唯一のターゲット） |

---

## 主要機能

### 道の駅
- 現在地周辺の道の駅を距離順に表示
- 施設詳細（設備・営業時間・公式サイト）
- フォトアルバム（1 施設あたり最大 3 枚、端末保存）
- お気に入り・訪問済みフラグ
- 外部ナビアプリ（Apple Maps / Google Maps / Yahoo!カーナビ / Waze）への誘導
- データ出典: 一般社団法人 全国道の駅連絡会（利用許諾済み）

### 走行情報
- 現在速度・方位（CoreLocation）

---

## エンタイトルメント

### Info.plist 必須キー
```
NSLocationAlwaysAndWhenInUseUsageDescription
NSLocationWhenInUseUsageDescription
NSPhotoLibraryUsageDescription
UIBackgroundModes: [location]
```

---

## 写真ストレージ

`StationPhotoStore` が以下のパスに JPEG で保存:
```
<Application Support>/Albums/<stationId>/photo_1.jpg  ～  photo_3.jpg
```
- 最大寸法: 1024px
- JPEG 品質: 0.72

---

## 現在のフェーズと未対応タスク

### ✅ 完了
- 道の駅データ実装・表示
- 施設詳細・フォトアルバム
- お気に入り・訪問済み管理
- 外部ナビアプリ連携
- 設定画面・クレジット表示
- プライバシーポリシー（GitHub Pages）

### 🔲 Phase 1-D（App Store 申請）
- [ ] App Store Connect 設定（日本国内限定）
- [ ] TestFlight 配布
- [ ] App Store 審査提出

---

## コーディング規約

- **命名**: Swift API Design Guidelines 準拠（lowerCamelCase）
- **アーキテクチャ**: MVVM + SwiftUI `@Observable`
- **非同期処理**: `async/await`（Combine は使用しない）
- **エラーハンドリング**: `Result` 型または `throws`
- **コメント**: 公開 API は `/// DocComment`
- **テスト**: XCTest（Unit Test）

---

## 参考リンク

- 全国道の駅連絡会: http://www.michi-no-eki.jp/
- GitHub Pages（プライバシーポリシー）: https://osprey74.github.io/michi-navi/privacy.html
