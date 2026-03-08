# Michi-navi（道ナビ）

**走行中の iPhone をもっとスマートに。Apple CarPlay 対応ドライビングタスクアプリ。**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: iOS 17+](https://img.shields.io/badge/Platform-iOS%2017%2B-lightgrey)](https://developer.apple.com/ios/)
[![CarPlay: Driving Task](https://img.shields.io/badge/CarPlay-Driving%20Task-3C7B91)](https://developer.apple.com/carplay/)

---

## 概要

Michi-navi は、走行中に最小限の操作でドライブ補助情報を提供する CarPlay 対応 iPhone アプリです。

- 現在地・速度のリアルタイム表示
- 周辺施設（給油所 / SA・PA / コンビニ / 食事）の検索
- 気象情報（WeatherKit）
- CarPlay ダッシュボードへのウィジェット・Live Activity 表示

## 要件

- **iPhone**: iOS 17.0 以上
- **CarPlay**: 対応車または社外ナビ
- **Xcode**: 26.3 以上（Apple Silicon Mac 推奨）

## セットアップ

```bash
git clone https://github.com/osprey74/michi-navi.git
cd michi-navi
open MichiNavi.xcodeproj
```

### CarPlay Simulator のセットアップ

1. Xcode → Xcode メニュー → Open Developer Tool → Additional Tools for Xcode
2. CarPlay Simulator をインストール
3. Xcode Simulator でアプリを起動後、CarPlay Simulator を起動して接続

### エンタイトルメント申請

CarPlay Driving Task エンタイトルメントは Apple への申請が必要です。

1. [Apple Developer Program](https://developer.apple.com/programs/) に加入
2. [CarPlay 開発者ページ](https://developer.apple.com/carplay/) からエンタイトルメントを申請
3. 承認後、Xcode の Signing & Capabilities に追加

## 開発ロードマップ

| Phase | 内容 | 状態 |
|-------|------|------|
| Phase 0 | Xcode プロジェクト作成・CarPlay 動作確認 | 🔲 準備中 |
| Phase 1-A | CoreLocation・MapKit・速度表示 | 🔲 |
| Phase 1-B | CarPlay テンプレート・POI 検索 | 🔲 |
| Phase 1-C | WeatherKit・Live Activity・Widget | 🔲 |
| Phase 1-D | App Store 審査・公開 | 🔲 |
| Phase 2 | Navigation エンタイトルメント・フルナビ | 🔲 |

## ライセンス

MIT License — © 2026 Sohshi / Polaris Solutions Inc.
