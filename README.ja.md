# Michi-Navi（ミチナビ）

Raspberry Pi 4をベースとした車載型ドライブアシスタント端末です。GPSによるリアルタイム位置表示とOpenStreetMap地図を組み合わせ、進行方向前方の道の駅や近隣の観光情報をサジェストします。

## 主な機能

- **リアルタイム地図表示** — OpenStreetMapタイルをPySide6/QPainterでネイティブ描画。現在位置・進行方向マーカーをオーバーレイ
- **道の駅サジェスト** — 進行方向±45°内の道の駅を距離順にリスト表示
- **近隣観光情報** — 現在位置の市町村の観光ワンポイント情報を表示
- **オフライン対応** — 地図タイル・POIデータをローカルキャッシュし、通信圏外でも動作
- **速度・方位・標高表示** — GPSテレメトリをステータスバーにリアルタイム表示
- **タッチ操作対応** — 5インチタッチスクリーンでのピンチズーム・ドラッグパン・タップ詳細表示

## 技術スタック

| 項目 | 技術 |
|------|------|
| プラットフォーム | Raspberry Pi 4 Model B |
| OS | Raspberry Pi OS Lite 64-bit (Bookworm) |
| 言語 | Python 3.11+ |
| GUI | PySide6 (Qt 6) |
| 地図タイル | OpenStreetMapラスタータイル |
| GPS | gpsd + USB GPSドングル (NEO-M8N / VK-162) |
| データベース | SQLite（R-Tree空間インデックス付き） |

## プロジェクト構成

```
Michi-Navi/
├── main.py                  # エントリポイント
├── app/
│   ├── widgets/             # MapWidget, InfoPanel, StatusBar, DetailPanel
│   ├── core/                # GPSManager, TileManager, POISearchEngine, GeoUtils
│   ├── data/                # DB管理, データインポーター
│   └── config/              # 設定値, カラーテーマ
├── data/                    # SQLite DB & タイルキャッシュ (gitignore対象)
├── scripts/                 # データインポート, タイルDL, Piセットアップ
├── fonts/                   # 日本語フォント (gitignore対象)
├── resources/               # アイコン, 地図マーカー
├── tests/                   # ユニットテスト
└── docs/                    # 設計ドキュメント
```

## 開発状況

| フェーズ | 進捗 |
|----------|------|
| Phase 1: 基盤構築 | 100% |
| Phase 2: 地図エンジン | 100% |
| Phase 3: GPS統合 | 0% |
| Phase 4: POI検索・情報表示 | 0% |
| Phase 5: 磨き込み・車載対応 | 0% |

**現在:** Phase 1-2 完了。OSMタイル描画、道の駅マーカー（1,204件）、キーボード/マウス/タッチ操作、2階層タイルキャッシュを搭載したインタラクティブデモが動作可能。

## クイックスタート（PCデモ）

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install PySide6 requests
python scripts/import_stations.py  # 道の駅1,204件をインポート
python main.py
```

**操作方法:** 矢印キーで移動、Q/Eで回転、+/-でズーム、マウスドラッグでパン、ダブルクリックで復帰、マウスホイールでズーム。

## セットアップ

```
pip install -r requirements.txt
```

## ライセンス

TBD

## 地図の帰属表示

本アプリケーションは [OpenStreetMap](https://www.openstreetmap.org/) の地図タイルを使用しています。
© OpenStreetMap contributors. タイルは [ODbL](https://opendatacommons.org/licenses/odbl/) ライセンスの下で提供されています。
