# Michi-Navi タスク管理

## 進捗サマリー

| フェーズ | 完了 | 合計 | 進捗 |
|----------|------|------|------|
| Phase 1: 基盤構築 | 0 | 10 | 0% |
| Phase 2: 地図エンジン | 0 | 11 | 0% |
| Phase 3: GPS統合 | 0 | 9 | 0% |
| Phase 4: POI検索・情報表示 | 0 | 9 | 0% |
| Phase 5: 磨き込み・車載対応 | 0 | 9 | 0% |
| **全体** | **0** | **48** | **0%** |

---

## Phase 1: 基盤構築

### 1.1 開発環境セットアップ
- [ ] Python 仮想環境の作成と依存パッケージのインストール
- [ ] PySide6 の動作確認（Hello World ウィンドウ表示）

### 1.2 メインウィンドウ・基本レイアウト
- [ ] QMainWindow の雛形作成 (`app/main_window.py`)
- [ ] 3エリア構成のレイアウト実装（StatusBar 40px / MapWidget 520x440 / InfoPanel 280px）
- [ ] エントリポイント (`main.py`) の実装

### 1.3 道の駅データベース構築
- [ ] SQLite データベーススキーマ作成 (`roadside_stations`, `tourism_spots`, R-Tree インデックス)
- [ ] 道の駅 API からのデータ取り込みスクリプト作成 (`scripts/import_stations.py`)
- [ ] データインポートの実行と検証

### 1.4 座標計算ユーティリティ
- [ ] `app/core/geo_utils.py` の実装（`deg2tile`, `tile2deg`, `haversine`, `bearing`, `is_ahead`）
- [ ] ユニットテスト作成 (`tests/test_geo_utils.py`)

---

## Phase 2: 地図エンジン

### 2.1 TileManager
- [ ] ディスクキャッシュ実装（`tiles/{z}/{x}/{y}.png` 形式、容量ベースエビクション max 8GB）
- [ ] メモリキャッシュ実装（LRU 方式、最大 512 タイル QPixmap 保持）
- [ ] バックグラウンドスレッドでの OSM タイルダウンロード（User-Agent 設定、レート制限遵守）
- [ ] ユニットテスト作成 (`tests/test_tile_manager.py`)

### 2.2 MapWidget
- [ ] QPainter によるタイル描画実装（タイル範囲算出 → 取得 → 描画パイプライン）
- [ ] サブピクセルオフセットによるスムーズスクロール
- [ ] オーバーレイ描画（現在位置マーカー、方位インジケータ）
- [ ] OSM 帰属表示 "© OpenStreetMap contributors" の地図上への描画

### 2.3 タッチ操作
- [ ] ピンチイン/アウトによるズームレベル変更 (zoom 8-18)
- [ ] ドラッグによる地図パン（自動追従一時停止）
- [ ] ダブルタップで現在位置に復帰（自動追従再開）

---

## Phase 3: GPS統合

### 3.1 Raspberry Pi 環境セットアップ
- [ ] Raspberry Pi OS Lite (Bookworm 64-bit) のインストール
- [ ] Wayland (labwc) 最小構成デスクトップの設定
- [ ] gpsd のインストールと USB GPS ドングルの接続確認

### 3.2 GPSManager
- [ ] QThread ベースの GPS ワーカー実装 (`app/core/gps_manager.py`)
- [ ] gpsd からの 1Hz データ取得と Qt シグナル発行（`position_updated`, `satellites_updated`, `fix_lost`）
- [ ] COG 安定化処理（低速 5km/h 未満で最後の確定方位を保持）

### 3.3 地図連携・ステータス表示
- [ ] 地図上の現在位置マーカー描画（円＋方向三角）
- [ ] 自動追従モード（GPS 更新に連動して地図中心を移動）
- [ ] StatusBar 実装（GPS 状態、座標、速度、方位、時刻表示）(`app/widgets/status_bar.py`)

---

## Phase 4: POI検索・情報表示

### 4.1 POISearchEngine
- [ ] R-Tree 粗フィルタによる矩形範囲検索の実装
- [ ] Haversine 距離計算 + 進行方向 ±45° フィルタの統合
- [ ] `search_ahead()` メソッド（距離順ソート、最大 10 件返却）
- [ ] ユニットテスト作成 (`tests/test_poi_search.py`)

### 4.2 InfoPanel
- [ ] 道の駅リスト表示ウィジェット（名称・距離・方位）(`app/widgets/info_panel.py`)
- [ ] 近隣市町村の観光ワンポイント情報表示
- [ ] GPS 更新に連動したリストの自動更新

### 4.3 地図上 POI 表示・詳細パネル
- [ ] 地図上への道の駅ピン描画
- [ ] 道の駅ピンタップ / リストタップで詳細パネルスライドイン表示 (`app/widgets/detail_panel.py`)

---

## Phase 5: 磨き込み・車載対応

### 5.1 UI 仕上げ
- [ ] デイ/ナイトモード切替実装（カラーテーマ定義 `app/config/themes.py`）
- [ ] 設定画面の実装（検索半径、モード切替、タイルキャッシュ管理、GPS ステータス）
- [ ] 日本語フォント (Noto Sans JP) の組み込みとレンダリング確認

### 5.2 車載・運用対応
- [ ] キオスクモード起動設定（systemd サービス化）
- [ ] overlay-fs による Read-Only FS 化（電源断対策）
- [ ] IGN 信号検出による安全シャットダウンスクリプト
- [ ] 前回終了位置の保存と起動時復元（GPS 初期測位遅延対策）

### 5.3 タイル事前ダウンロード
- [ ] タイル事前ダウンロードスクリプト作成 (`scripts/download_tiles.py`)
- [ ] エリア・ズームレベル指定によるバッチダウンロード（レート制限遵守）

---

## 備考

- 設計書: [Michi-Navi_Design_Document.md](Michi-Navi_Design_Document.md)
- 道の駅 API: https://it-social.net/roadside_station/
- OSM Tile Policy: https://operations.osmfoundation.org/policies/tiles/
