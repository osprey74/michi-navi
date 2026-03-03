# Michi-Navi（ミチナビ）

## ドライブアシスタント端末 詳細設計書

- **Version:** 1.0
- **Date:** 2026-03-03
- **Platform:** Raspberry Pi 4 Model B

---

## 目次

1. [プロジェクト概要](#1-プロジェクト概要)
2. [システムアーキテクチャ](#2-システムアーキテクチャ)
3. [ハードウェア構成](#3-ハードウェア構成)
4. [ソフトウェアスタック](#4-ソフトウェアスタック)
5. [データ設計](#5-データ設計)
6. [地図表示エンジン設計](#6-地図表示エンジン設計)
7. [GPS連携設計](#7-gps連携設計)
8. [検索ロジック設計](#8-検索ロジック設計)
9. [UI/UX設計](#9-uiux設計)
10. [ディレクトリ構成](#10-ディレクトリ構成)
11. [開発ロードマップ](#11-開発ロードマップ)
12. [技術的リスクと対策](#12-技術的リスクと対策)

---

## 1. プロジェクト概要

### 1.1 目的・コンセプト

Michi-Navi（ミチナビ）は、Raspberry Pi 4をベースとした車載型ドライブアシスタント端末である。GPSによる現在位置と進行方向をリアルタイムで取得し、OpenStreetMapタイルを用いたネイティブ地図表示と共に、近隣の道の駅・観光情報をサジェストする。

商用カーナビとは異なり、「ドライブ中の発見と楽しみ」を重視し、進行方向前方の道の駅や地域の観光ワンポイント情報をプッシュ型で提供する点が特徴である。

### 1.2 主要機能一覧

| # | 機能名 | 説明 |
|---|--------|------|
| F1 | リアルタイム地図表示 | OpenStreetMapタイルを用いたネイティブ描画。現在位置・進行方向マーカーをオーバーレイ表示 |
| F2 | 道の駅サジェスト | 進行方向前方±45°内の道の駅を距離順にリスト表示。名称・距離・特色情報を含む |
| F3 | 近隣市町村観光情報 | 現在位置の市町村を判定し、観光ワンポイント情報を表示 |
| F4 | オフライン対応 | 地図タイル・道の駅データをローカルキャッシュし、通信圏外でも動作 |
| F5 | 速度・方位情報表示 | 現在速度・進行方位・標高・時刻をステータスバーに表示 |
| F6 | タッチ操作対応 | タッチディスプレイでのズーム・パン・情報詳細表示の操作 |

---

## 2. システムアーキテクチャ

### 2.1 全体構成

本システムは以下の4層構造で構成する。

```
+-----------------------------------------------------+
|  Presentation Layer (PySide6 / Qt6 Widgets)         |
|    MapWidget / InfoPanel / StatusBar                 |
+-----------------------------------------------------+
|  Application Layer (Python)                          |
|    GPSManager / POISearchEngine / TileManager        |
+-----------------------------------------------------+
|  Data Layer (SQLite / File Cache)                    |
|    poi.db / tiles/ / config.json                     |
+-----------------------------------------------------+
|  Hardware Abstraction Layer                          |
|    gpsd / Display (HDMI) / Network (Wi-Fi)           |
+-----------------------------------------------------+
```

### 2.2 データフロー

システム内のデータフローは以下の通りである。

```
GPS受信機 -> gpsd -> GPSManager (1Hzポーリング)
  +-> 現在位置(lat,lon) + 速度(speed) + 方位(course)
     |-> MapWidget: タイル読み込み -> 地図描画 -> マーカーオーバーレイ
     |-> POISearchEngine: 近傍検索 -> 方向フィルタ -> InfoPanel更新
     +-> StatusBar: 速度・方位・標高・時刻表示
```

### 2.3 スレッド構成

パフォーマンス確保のため、以下のスレッド分離を行う。

| スレッド | 責務 |
|----------|------|
| メインスレッド (Qt) | UI描画・イベントハンドリング・シグナル/スロット処理 |
| GPSワーカー (QThread) | gpsdとの通信、NMEA解析、位置情報のシグナル発行 (1Hz) |
| タイルローダー (QThread) | 地図タイルのディスク読み込み・ネットワークダウンロード・キャッシュ管理 |
| POI検索 (QThread) | 近傍検索・方向フィルタリング・結果ソートをバックグラウンドで実行 |

---

## 3. ハードウェア構成

### 3.1 部品リスト

| 部品 | 型番例 | 概算価格 | 備考 |
|------|--------|----------|------|
| Raspberry Pi 4 Model B | 4GB/8GB RAM | 手持ち | メインボード |
| ディスプレイ | 5インチ HDMIタッチ (800x480) | ¥4,000 | XPT2046タッチIC付き推奨 |
| GPSモジュール | NEO-M8N USBドングル型 | ¥1,500 | VK-162等でも可 |
| microSDカード | 32GB Class10 A2 | ¥800 | タイルキャッシュ用に大容量推奨 |
| 車載電源 | USB-C 5V/3Aシガーソケット | ¥1,500 | QC3.0対応推奨 |
| ヒートシンク | アルミヒートシンク+ファン | ¥800 | 夏場車内対策 |
| ケース | 3Dプリント or 市販ケース | ¥1,000 | ディスプレイ一体型が理想 |

**合計概算: ¥9,600**（Pi 4本体除く）

### 3.2 接続構成図

```
+------------------+    +------------------+
|  USB GPSドングル  |    |  Raspberry Pi 4  |
|  (VK-162等)      |USB |   4GB/8GB RAM    |
+--------+---------+    |                  |
         |              |  Wi-Fi: テザリング|
+------------------+    |  接続先          |
|  5" HDMI Touch   |    |                  |
|  Display 800x480 |HDMI|                  |
+--------+---------+    +--------+---------+
                                 | USB-C
                        +--------+---------+
                        |  車載シガー       |
                        |  USB-C 5V/3A     |
                        +------------------+
```

### 3.3 電源設計

- **入力:** 車載シガーソケット12V -> USB-C 5V/3A変換
- **安全シャットダウン:** GPIOピンでIGN信号を検出し、systemdサービスで安全なshutdownを実行
- **Read-Only FS:** overlay-fsを活用し、電源断時のSDカード破損を防止。タイルキャッシュ等の書き込みはtmpfs上に配置

---

## 4. ソフトウェアスタック

### 4.1 OS・ランタイム

| 項目 | 選定 |
|------|------|
| OS | Raspberry Pi OS Lite (64-bit, Bookworm) |
| デスクトップ環境 | Wayland (labwc) ※最小構成。アプリはキオスクモードで起動 |
| Python | 3.11+ (OS同梱版) |
| GPSデーモン | gpsd + python-gps |
| ディスプレイドライバ | KMS/DRM (Pi 4標準) |

### 4.2 フレームワーク選定: PySide6 (Qt6)

UIフレームワークとしてPySide6 (Qt for Python)を採用する。選定理由は以下の通り。

- **QPainterによる高速描画:** タイルベースの地図レンダリングをカスタムウィジェットで実装可能
- **日本語フォント完全対応:** TrueType/OpenTypeフォントをネイティブにレンダリング。Noto Sans JP等が使用可能
- **タッチ操作:** Qtのタッチイベントハンドリングでピンチズーム・スワイプを実装
- **シグナル/スロット:** スレッド間通信がQtのシグナル/スロット機構で安全に実現可能
- **クロスプラットフォーム:** 開発時はPC上でデバッグ、デプロイ時にPiで実行可能

### 4.3 主要ライブラリ一覧

| ライブラリ | 用途 | インストール |
|------------|------|-------------|
| PySide6 | GUIフレームワーク | `pip install PySide6` |
| gps3 | gpsdクライアント | `pip install gps3` |
| requests | HTTPクライアント (タイル取得) | `pip install requests` |
| Pillow | 画像処理 (タイル変換) | `pip install Pillow` |
| geopy | 距離計算・逆ジオコーディング | `pip install geopy` |

---

## 5. データ設計

### 5.1 道の駅データベース (SQLite)

道の駅APIから取得した全国約1,225駅のデータをSQLiteデータベースに格納する。後述の近傍検索最適化のためR-Treeインデックスを活用する。

**データソース:** https://it-social.net/roadside_station/

#### テーブル: roadside_stations

```sql
CREATE TABLE roadside_stations (
  id            TEXT PRIMARY KEY,  -- 登録番号 (5桁)
  name          TEXT NOT NULL,     -- 道の駅名
  prefecture    TEXT NOT NULL,     -- 都道府県
  municipality  TEXT,              -- 市町村
  latitude      REAL NOT NULL,     -- 緯度
  longitude     REAL NOT NULL,     -- 経度
  road_name     TEXT,              -- 登録路線名
  features      TEXT,              -- 特色・概要 (JSON)
  hours         TEXT,              -- 営業時間
  holidays      TEXT,              -- 定休日
  url           TEXT,              -- 公式サイトURL
  image_url     TEXT               -- 画像URL
);

-- 空間インデックス (R-Tree)
CREATE VIRTUAL TABLE stations_rtree USING rtree(
  id,
  min_lat, max_lat,
  min_lon, max_lon
);
```

#### テーブル: tourism_spots

```sql
CREATE TABLE tourism_spots (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,     -- スポット名
  municipality  TEXT NOT NULL,     -- 市町村
  prefecture    TEXT NOT NULL,     -- 都道府県
  latitude      REAL NOT NULL,
  longitude     REAL NOT NULL,
  category      TEXT,              -- カテゴリ(温泉/神社/景観等)
  description   TEXT,              -- ワンポイント説明
  source        TEXT               -- データソース
);
```

### 5.2 地図タイルキャッシュ

地図タイルはディスク上に以下のディレクトリ構造でキャッシュする。

```
tiles/
  +-- {zoom}/
  |   +-- {x}/
  |   |   +-- {y}.png     -- タイル画像 (256x256px)
  |   |   +-- ...
  +-- ...
```

- **タイルソース:** OpenStreetMapラスタータイル (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`)
- **事前ダウンロード:** ドライブ予定エリアのタイルをズームレベル8-15で事前取得するスクリプトを用意する。全国カバーは大容量となるため、ドライブ対象地域を限定してダウンロードする。

#### タイル容量の目安

| ズームレベル | 用途 | 範囲例 (100km x 100km) | 容量目安 |
|--------------|------|------------------------|----------|
| 8-10 | 広域俯瞰 | 全国 | 約200MB |
| 11-13 | 市町村レベル | 都道府県単位 | 約1-3GB |
| 14-15 | 街路レベル | ドライブルート周辺 | 約2-5GB |

推奨: 32GB microSDカードを使用し、ズームレベル8-13を広域で、レベル14-15は主要ルート周辺のみキャッシュする。

---

## 6. 地図表示エンジン設計

### 6.1 タイル座標計算

OpenStreetMapのスリッピーマップタイル方式に従い、緯度・経度からタイル座標を算出する。基本的な変換式は以下の通り。

```python
import math

def deg2tile(lat_deg, lon_deg, zoom):
    """lat/lonをタイル座標(x, y)に変換"""
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    x = int((lon_deg + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y

def tile2deg(x, y, zoom):
    """タイル座標を北西角のlat/lonに変換"""
    n = 2.0 ** zoom
    lon_deg = x / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    lat_deg = math.degrees(lat_rad)
    return lat_deg, lon_deg
```

### 6.2 MapWidget クラス設計

MapWidgetはQWidgetを継承し、QPainterでタイルを描画するカスタムウィジェットである。

#### レンダリングパイプライン

- **Step 1 - タイル範囲算出:** ウィジェットサイズと現在の中心座標から、表示に必要なタイルの範囲 (x_min, x_max, y_min, y_max) を計算
- **Step 2 - タイル取得:** TileManagerがキャッシュディレクトリを検索。ヒットすればQPixmapを返却、ミスすればバックグラウンドでダウンロードキューに追加
- **Step 3 - タイル描画:** `QPainter.drawPixmap()` で各タイルを配置。サブピクセルオフセットでスムーズなスクロールを実現
- **Step 4 - オーバーレイ:** 現在位置マーカー、道の駅ピン、方位インジケータをタイルの上に描画

#### タッチ操作

| 操作 | 挙動 |
|------|------|
| ピンチイン/アウト | ズームレベル変更 (zoom 8-18) |
| ドラッグ | 地図パン（ドラッグ中は自動追従を一時停止） |
| ダブルタップ | 現在位置に復帰（自動追従再開） |
| 道の駅ピンタップ | 詳細情報パネルをスライドイン表示 |

### 6.3 TileManager クラス設計

2階層キャッシュ戦略を採用する。

- **L1 - メモリキャッシュ:** LRU方式で最大512タイルをQPixmapとして保持 (約50MB)
- **L2 - ディスクキャッシュ:** `tiles/{z}/{x}/{y}.png` としてファイル保存。エビクションポリシーは容量ベース (max 8GB)

ディスクキャッシュにヒットしない場合のみ、バックグラウンドスレッドでOSMタイルサーバーからダウンロードし、両キャッシュに格納する。

---

## 7. GPS連携設計

### 7.1 gpsd構成

USB GPSドングルをgpsdデーモン経由で利用する。gpsdはデバイスの差異を吸収し、統一的なJSON APIを提供する。

```bash
# /etc/default/gpsd
DEVICES="/dev/ttyACM0"
GPSD_OPTIONS="-n"
START_DAEMON="true"
```

### 7.2 GPSManager クラス設計

GPSManagerはQThread上で動作し、1秒間隔でgpsdからデータを取得、QtシグナルでUIスレッドに通知する。

#### シグナル定義

```python
class GPSManager(QThread):
    # シグナル定義
    position_updated = Signal(float, float, float, float)
    #                        lat,   lon,   speed, course
    satellites_updated = Signal(int)  # 可視衛星数
    fix_lost = Signal()               # GPSフィックスロスト
```

### 7.3 進行方向算出

GPSのNMEAデータに含まれるCOG (Course Over Ground) を優先使用する。停車中や低速時 (5km/h未満) はCOGが不安定なため、最後に確定した方位を保持する。

```python
def get_stable_course(self, speed, raw_course):
    """COGの安定化処理"""
    if speed >= 5.0:  # km/h
        self._last_stable_course = raw_course
        return raw_course
    return self._last_stable_course
```

---

## 8. 検索ロジック設計

### 8.1 近傍検索アルゴリズム

近傍検索は2ステップで行う。まずR-Treeインデックスで矩形範囲の粗フィルタをかけ、その後候補に対してHaversine距離計算を行う。

#### Step 1: 矩形粗フィルタ (R-Tree)

```sql
-- 現在位置から+-0.5度（約50km）の矩形内を検索
SELECT s.* FROM roadside_stations s
JOIN stations_rtree r ON s.rowid = r.id
WHERE r.min_lat <= :lat + 0.5 AND r.max_lat >= :lat - 0.5
  AND r.min_lon <= :lon + 0.5 AND r.max_lon >= :lon - 0.5;
```

#### Step 2: Haversine距離計算

```python
from math import radians, sin, cos, sqrt, atan2

def haversine(lat1, lon1, lat2, lon2):
    """2点間の距離を返却 (km)"""
    R = 6371.0  # 地球半径
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1-a))
```

### 8.2 進行方向フィルタリング

現在地から各道の駅への方位角を計算し、進行方向 (COG) との差が+-45度以内のものを「前方」と判定する。

```python
from math import atan2, degrees, radians, sin, cos

def bearing(lat1, lon1, lat2, lon2):
    """現在地から目標地への方位角 (0-360度)"""
    dlon = radians(lon2 - lon1)
    x = sin(dlon) * cos(radians(lat2))
    y = cos(radians(lat1)) * sin(radians(lat2)) - \
        sin(radians(lat1)) * cos(radians(lat2)) * cos(dlon)
    return (degrees(atan2(x, y)) + 360) % 360

def is_ahead(course, bearing_to_poi, threshold=45):
    """進行方向前方か判定"""
    diff = abs(course - bearing_to_poi)
    if diff > 180:
        diff = 360 - diff
    return diff <= threshold
```

### 8.3 検索パイプライン統合

```python
class POISearchEngine:
    def search_ahead(self, lat, lon, course, max_distance=50):
        """進行方向前方の道の駅を距離順で返却"""
        # Step 1: R-Tree粗フィルタ
        candidates = self.db.query_nearby(lat, lon, radius_deg=0.5)
        results = []
        for poi in candidates:
            dist = haversine(lat, lon, poi.lat, poi.lon)
            if dist > max_distance:
                continue
            brg = bearing(lat, lon, poi.lat, poi.lon)
            if is_ahead(course, brg):
                results.append((dist, poi))
        return sorted(results, key=lambda x: x[0])[:10]
```

---

## 9. UI/UX設計

### 9.1 画面レイアウト (メイン画面)

メイン画面は3エリア構成とする。800x480ピクセルのディスプレイに最適化する。

```
+-----------------------------------------------------------+
|  StatusBar: 40px                                          |
|  [GPS*] 43.06N 141.35E | 62km/h | NNE | 14:32            |
+---------------------------------------+-------------------+
|                                       |  InfoPanel        |
|                                       |  280px            |
|      MapWidget                        |                   |
|      520px x 440px                    |  > 道の駅XX       |
|                                       |    12.3km NE      |
|      [  現在位置マーカー  ]            |                   |
|      [  道の駅ピン       ]            |  > 道の駅YY       |
|                                       |    25.7km N       |
|                                       |                   |
|                                       |  ---------        |
|                                       |  [観光情報]        |
|                                       |  札幌市: ...      |
+---------------------------------------+-------------------+
```

### 9.2 カラースキーム

車内の明るい環境での視認性を確保しつつ、夜間のグレアを低減する2モードを用意する。

| 要素 | デイモード | ナイトモード | 備考 |
|------|------------|--------------|------|
| 背景 | `#FFFFFF` | `#1A1A2E` | |
| プライマリ | `#3C7B91` | `#5DADE2` | ヘッダー・アクティブ要素 |
| アクセント | `#0582AF` | `#2ECC71` | リンク・ハイライト |
| テキスト | `#2C3E50` | `#ECF0F1` | 本文テキスト |
| 警告 | `#E74C3C` | `#E74C3C` | 速度超過等 |
| 現在位置マーカー | `#E74C3C` | `#FF6B6B` | 円+方向三角 |
| 道の駅ピン | `#27AE60` | `#2ECC71` | 地図上マーカー |

### 9.3 画面遷移

```
メイン画面 (地図+情報パネル)
  |-- 道の駅タップ -> 道の駅詳細パネル (スライドイン)
  |                   +-- スワイプ左 -> 閉じる
  |-- ダブルタップ -> 現在位置に復帰
  +-- 設定ボタン -> 設定画面
       |-- 検索半径設定 (10/25/50/100km)
       |-- デイ/ナイトモード切替
       |-- タイルキャッシュ管理
       +-- GPSステータス確認
```

---

## 10. ディレクトリ構成

```
Michi-Navi/
|-- main.py                   # エントリポイント
|-- app/
|   |-- __init__.py
|   |-- main_window.py        # QMainWindow
|   |-- widgets/
|   |   |-- map_widget.py     # 地図描画ウィジェット
|   |   |-- info_panel.py     # 情報パネル
|   |   |-- status_bar.py     # ステータスバー
|   |   +-- detail_panel.py   # 道の駅詳細スライド
|   |-- core/
|   |   |-- gps_manager.py    # GPSワーカースレッド
|   |   |-- tile_manager.py   # タイル取得・キャッシュ
|   |   |-- poi_search.py     # POI検索エンジン
|   |   +-- geo_utils.py      # 座標計算ユーティリティ
|   |-- data/
|   |   |-- db_manager.py     # SQLite接続管理
|   |   +-- data_importer.py  # 道の駅APIデータ取り込み
|   +-- config/
|       |-- settings.py       # 設定値定義
|       +-- themes.py         # カラーテーマ定義
|-- data/
|   |-- poi.db                # SQLiteデータベース
|   +-- tiles/                # タイルキャッシュ
|-- scripts/
|   |-- import_stations.py    # 道の駅データインポート
|   |-- download_tiles.py     # タイル事前ダウンロード
|   +-- setup_pi.sh           # Raspberry Piセットアップスクリプト
|-- fonts/
|   +-- NotoSansJP-*.ttf      # 日本語フォント
|-- resources/
|   |-- icons/                # UIアイコン (SVG)
|   +-- markers/              # 地図マーカー画像
|-- tests/
|   |-- test_geo_utils.py
|   |-- test_poi_search.py
|   +-- test_tile_manager.py
|-- requirements.txt
+-- README.md
```

---

## 11. 開発ロードマップ

### Phase 1: 基盤構築 (目安1-2週間)

- 開発環境セットアップ (PC上でPySide6開発環境構築)
- PySide6でウィンドウ表示・基本レイアウト実装
- 道の駅APIからデータ取り込みスクリプト作成、SQLiteデータベース構築
- 座標計算ユーティリティ (geo_utils.py) の実装とテスト

### Phase 2: 地図エンジン (目安2-3週間)

- TileManager実装 (ディスクキャッシュ+メモリキャッシュ)
- MapWidget実装 (QPainterでタイル描画)
- タッチ操作実装 (ピンチズーム・ドラッグパン)
- 固定座標でのデモ動作確認 (PC上)

### Phase 3: GPS統合 (目安1-2週間)

- Raspberry Pi環境セットアップ (OS・ディスプレイ・gpsd)
- GPSManager実装 (gpsd連携)
- 地図上の現在位置マーカー・自動追従
- StatusBar実装 (速度・方位・時刻表示)

### Phase 4: POI検索・情報表示 (目安1-2週間)

- POISearchEngine実装 (近傍検索+方向フィルタ)
- InfoPanel実装 (道の駅リスト表示)
- 地図上の道の駅ピン表示
- 詳細パネルのスライドインUI

### Phase 5: 磨き込み・車載対応 (目安1-2週間)

- デイ/ナイトモード切替
- キオスクモード起動設定 (systemdサービス化)
- 電源断対策 (Read-Only FS・安全シャットダウン)
- 車載テスト・パフォーマンスチューニング

---

## 12. 技術的リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| PySide6のPi4パフォーマンス | 地図描画が重くなる可能性 | QPixmapキャッシュ活用、可視範囲のみ描画、OpenGLバックエンド検討 |
| 夏場の車内温度 | Pi4のサーマルスロットリング | ヒートシンク+ファン、直射日光回避、温度モニタリング |
| OSMタイル利用規約 | 過度なダウンロードでブロック可能性 | 事前ダウンロード時はレート制限遵守、User-Agent設定 |
| 電源断によるSD破損 | ファイルシステム破損 | overlay-fsでルートFSをRead-Only化 |
| GPS初期測位の遅延 | 起動後しばらく地図が動かない | 前回終了位置を保存し初期表示に使用 |
| 道の駅データの鮮度 | 情報が古くなる | Wi-Fi接続時に定期的にAPIから差分更新 |

### OSMタイル利用についての重要な注意事項

OpenStreetMapタイルサーバーの利用には、以下の利用規約を遵守する必要がある。

- **User-Agent設定必須:** アプリケーション名とバージョンを含むユニークなUser-Agentを設定
- **レート制限:** 大量ダウンロードは避け、適切なキャッシュ戦略を実装
- **帰属表示:** 地図上に "(C) OpenStreetMap contributors" の帰属表示が必須
- **代替タイルサーバー:** 大規模な事前ダウンロードには自前タイルサーバー構築が推奨

---

## 参考リンク

| リソース | URL |
|----------|-----|
| 道の駅API | https://it-social.net/roadside_station/ |
| 道の駅API利用方法 | https://it-social.net/roadside_station/usage.html |
| OSM Tile Usage Policy | https://operations.osmfoundation.org/policies/tiles/ |
| PySide6 公式ドキュメント | https://doc.qt.io/qtforpython-6/ |
| gpsd リファレンス | https://gpsd.gitlab.io/gpsd/ |
| OSM Slippy Map Tilenames | https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames |

---

*End of Document*
