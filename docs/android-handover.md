# Michi-Navi Android版 開発引き継ぎ資料

作成日: 2026-03-27
iOS版最終コミット: `f731b99`（main ブランチ）

---

## 1. アプリ概要

**Michi-Navi** はドライブ中に最小限の操作でドライブ補助情報を提供するアプリです。

### 主な機能

| 機能 | 説明 |
|------|------|
| 地図表示 | 現在地・速度・方位のリアルタイム表示 |
| 道の駅マッピング | 全国約1,200件をビューポート連動で地図上に表示 |
| 道の駅詳細 | 写真・施設設備・公式サイトリンク |
| 施設POI表示 | GS / コンビニ / レストラン / 駐車場 / RVパーク 切替 |
| 目的地ナビ | 道の駅またはRVパークを検索し地図アプリでナビ開始 |
| 広域/詳細ズーム | ワンタップで120km広域 / 300m詳細に切替 |
| 速度連動オートズーム | 速度に応じて地図縮尺を自動調整 |

### 対応していない機能（iOS版未実装のためAndroid版でも保留）

- RVパーク自前データ（JRVA認定約608件）— データ利用問合せ中
- WeatherKit / 気象情報表示
- Live Activity / Widget
- Android Auto 対応（iOS版のCarPlay相当）

---

## 2. iOS版との技術スタック対応表

| 機能 | iOS版 | Android版 推奨 |
|------|-------|---------------|
| 言語 | Swift 6.x | Kotlin |
| UI | SwiftUI | Jetpack Compose |
| アーキテクチャ | MVVM + @Observable | MVVM + StateFlow |
| 地図 | MapKit | Google Maps SDK または Mapbox |
| 位置情報 | CoreLocation | FusedLocationProviderClient |
| コンパス | CLLocationManager | SensorManager |
| 非同期処理 | Swift async/await | Kotlin Coroutines |
| 状態管理 | @Observable + didSet | ViewModel + StateFlow |
| 設定永続化 | UserDefaults | DataStore Preferences |
| JSONパース | Codable | kotlinx.serialization / Gson |
| 車載連携 | CarPlay Driving Task | Android Auto（別途申請） |
| ナビゲーション起動 | Apple Maps | Google Maps Intent |

---

## 3. データモデル定義

### 3-1. RoadsideStation（道の駅）

iOS版: `MichiNavi/Shared/Models/RoadsideStation.swift`

```kotlin
data class RoadsideStation(
    val id: String,
    val name: String,
    val prefecture: String?,       // 都道府県
    val municipality: String?,     // 市町村
    val latitude: Double,
    val longitude: Double,
    @SerialName("road_name")
    val roadName: String?,         // 路線名（例: "中央道"）
    val features: List<String>,    // 施設キー配列
    val url: String?,              // 公式サイトURL
    @SerialName("image_url")
    val imageUrl: String?          // 写真URL
)
```

**施設キー（features）一覧 — 21種類**

| キー | 日本語ラベル | 説明 |
|------|------------|------|
| `atm` | ATM | |
| `restaurant` | レストラン | |
| `onsen` | 温泉 | |
| `ev_charger` | EV充電 | |
| `wifi` | Wi-Fi | |
| `baby_room` | 授乳室 | |
| `disabled_toilet` | 障害者トイレ | |
| `information` | 情報コーナー | |
| `shop` | 物販 | |
| `experience` | 体験施設 | |
| `museum` | 資料館 | |
| `park` | 公園 | |
| `hotel` | 宿泊 | |
| `rv_park` | RVパーク | |
| `dog_run` | ドッグラン | |
| `bicycle_rental` | レンタサイクル | |
| `camping` | キャンプ | |
| `footbath` | 足湯 | |

### 3-2. NearbyStation（検索結果）

```kotlin
data class NearbyStation(
    val station: RoadsideStation,
    val distanceKm: Double,        // Haversine距離
    val bearing: Double,           // 方位角 0–360°
) {
    val cardinalDirection: String  // 16方位文字列（N, NE, E...）
    val distanceText: String       // "X.X km" または "XXX m"
}
```

### 3-3. AppSettings（設定項目）

iOS版: `MichiNavi/Shared/Models/AppSettings.swift`

DataStore Preferences で永続化推奨。

| 設定項目 | キー | デフォルト値 | 説明 |
|---------|------|------------|------|
| ズームボタン位置 | `zoom_position` | `"right"` | `"left"` / `"right"` |
| GS表示 | `show_gas_stations` | `true` | |
| コンビニ表示 | `show_food_markets` | `false` | |
| レストラン表示 | `show_restaurants` | `false` | |
| 駐車場表示 | `show_parking` | `false` | |
| RVパーク表示 | `show_rv_parks` | `true` | |

---

## 4. ロジック移植ガイド

### 4-1. GeoUtils（地理計算）

iOS版: `MichiNavi/Shared/Services/GeoUtils.swift`

#### Haversine公式（2点間距離）

```kotlin
object GeoUtils {
    private const val EARTH_RADIUS_KM = 6371.0

    fun haversine(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double
    ): Double {
        val dLat = Math.toRadians(toLat - fromLat)
        val dLon = Math.toRadians(toLon - fromLon)
        val a = sin(dLat / 2).pow(2) +
                cos(Math.toRadians(fromLat)) *
                cos(Math.toRadians(toLat)) *
                sin(dLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_KM * c
    }
```

> **注意:** Android の `Location.distanceTo()` はAndroid APIで利用可能ですが、精度・一貫性のためGeoUtils自前実装推奨。

#### 方位角計算（Bearing）

```kotlin
    fun bearing(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double
    ): Double {
        val dLon = Math.toRadians(toLon - fromLon)
        val lat1 = Math.toRadians(fromLat)
        val lat2 = Math.toRadians(toLat)
        val x = sin(dLon) * cos(lat2)
        val y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        val bearing = Math.toDegrees(atan2(x, y))
        return (bearing + 360) % 360
    }
```

#### 前方判定（IsAhead）

```kotlin
    fun isAhead(heading: Double, bearingToTarget: Double, threshold: Double = 45.0): Boolean {
        var diff = bearingToTarget - heading
        while (diff > 180) diff -= 360
        while (diff < -180) diff += 360
        return abs(diff) <= threshold
    }
```

#### 16方位変換

```kotlin
    private val CARDINALS = arrayOf(
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
    )

    fun cardinalDirection(bearing: Double): String {
        val index = ((bearing + 11.25) % 360 / 22.5).toInt()
        return CARDINALS[index % 16]
    }
}
```

### 4-2. RoadsideStationService

iOS版: `MichiNavi/Shared/Services/RoadsideStationService.swift`

#### 近隣道の駅検索ロジック

```kotlin
fun updateNearbyStations(
    lat: Double, lon: Double,
    heading: Double,
    speedKmh: Double = 0.0,
    maxDistanceKm: Double = 100.0,
    maxResults: Int = 10
) {
    val allInRange = allStations
        .map { station ->
            val dist = GeoUtils.haversine(lat, lon, station.latitude, station.longitude)
            val brg = GeoUtils.bearing(lat, lon, station.latitude, station.longitude)
            NearbyStation(station, dist, brg)
        }
        .filter { it.distanceKm <= maxDistanceKm }
        .sortedBy { it.distanceKm }

    // stationsInRange: 範囲内全件（地図ピン用）
    stationsInRange = allInRange

    val isDriving = speedKmh > 5.0
    nearbyStations = if (isDriving) {
        // 走行中: 前方±45°のみ
        allInRange.filter { GeoUtils.isAhead(heading, it.bearing) }
                  .take(maxResults)
    } else {
        // 停車中: 全方位から近い順
        allInRange.take(maxResults)
    }
}
```

#### 表示領域フィルタ（ビューポート連動）

```kotlin
fun updateVisibleStations(
    centerLat: Double, centerLon: Double,
    latitudeDelta: Double, longitudeDelta: Double
) {
    val minLat = centerLat - latitudeDelta / 2
    val maxLat = centerLat + latitudeDelta / 2
    val minLon = centerLon - longitudeDelta / 2
    val maxLon = centerLon + longitudeDelta / 2
    visibleStations = allStations.filter { station ->
        station.latitude in minLat..maxLat &&
        station.longitude in minLon..maxLon
    }
}
```

#### 都道府県・市町村グループ化

47都道府県の標準順序（iOS版と同様）:

```kotlin
val PREFECTURE_ORDER = listOf(
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
    "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
    "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
    "岐阜県", "静岡県", "愛知県", "三重県",
    "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
    "鳥取県", "島根県", "岡山県", "広島県", "山口県",
    "徳島県", "香川県", "愛媛県", "高知県",
    "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
)
```

### 4-3. 速度→ズーム段階マッピング

iOS版: `ContentView.swift` の `MapConstants` と `zoomLevel(forSpeed:)`

```kotlin
object MapConstants {
    // 1km ≈ 0.009度（緯度）
    const val WIDE_ZOOM_DEGREES = 120 * 0.009   // 1.08° = 短辺120km
    const val DETAIL_ZOOM_DEGREES = 0.3 * 0.009 // 0.0027° = 短辺300m
}

fun zoomLevelForSpeed(speedKmh: Double): Double {
    val fullSpan = MapConstants.WIDE_ZOOM_DEGREES
    return when {
        speedKmh < 5   -> fullSpan          // 停車中: 120km広域
        speedKmh < 30  -> fullSpan * 0.15   // 低速: 18km
        speedKmh < 60  -> fullSpan * 0.3    // 市街地: 36km
        speedKmh < 100 -> fullSpan * 0.5    // 一般道: 60km
        else           -> fullSpan * 0.7    // 高速: 84km
    }
}
```

> **注意:** Google Maps SDK のズームレベルはMapKitとは異なります（度数ではなくズーム値0–21）。`latitudeDeltaToZoomLevel()` などの変換が別途必要です。

### 4-4. 位置情報サービス

iOS版: `MichiNavi/Shared/Services/LocationService.swift`

```kotlin
// FusedLocationProviderClient 設定値
val locationRequest = LocationRequest.Builder(
    Priority.PRIORITY_HIGH_ACCURACY,
    500L  // インターバル 0.5秒
).apply {
    setMinUpdateDistanceMeters(5f)      // 5m移動で更新
    setWaitForAccurateLocation(false)
}.build()

// コンパス（方位）
// SensorManager + Sensor.TYPE_ROTATION_VECTOR を使用
// 5°以上変化で更新（iOS の headingFilter = 5 相当）

// 速度変換
val speedKmh = location.speed * 3.6f   // m/s → km/h
val normalizedSpeed = if (speedKmh < 0) 0.0 else speedKmh.toDouble()
```

---

## 5. データファイル

### 5-1. 道の駅JSONデータ

iOS版: `MichiNavi/MichiNavi/Resources/roadside_stations.json`

**JSONスキーマ:**

```json
[
  {
    "id": "string（ユニークID）",
    "name": "string（道の駅名）",
    "prefecture": "string | null（都道府県）",
    "municipality": "string | null（市町村）",
    "latitude": 35.6762,
    "longitude": 139.6503,
    "road_name": "string | null（路線名）",
    "features": ["atm", "restaurant", "wifi"],
    "url": "string | null（公式サイトURL）",
    "image_url": "string | null（写真URL）"
  }
]
```

**データ規模:** 約1,200件（全国の道の駅）

**Android向け配置場所:** `app/src/main/assets/roadside_stations.json`

---

## 6. 画面構成

### 6-1. メイン画面（地図画面）

iOS版: `MichiNavi/Features/Map/ContentView.swift`

**レイアウト構成:**

```
[全画面]
├── 地図（ベースレイヤー）
│   ├── ユーザー現在地マーカー
│   └── 道の駅ピン（ビューポート内の全件・オレンジ色）
│
└── オーバーレイ
    ├── 左上: 設定ボタン（歯車アイコン）
    └── 下部（左右は設定で切替可能）
        ├── ズームボタン群
        │   ├── 広域ボタン（120km）
        │   └── 詳細ボタン（300m）
        ├── 目的地ボタン（メニュー）
        │   ├── 道の駅 → 道の駅選択画面
        │   └── RVパーク → RVパーク検索画面
        └── 情報表示
            ├── 速度（XX km/h）
            └── 天気テキスト（未実装）
```

**インタラクション:**

| 操作 | 動作 |
|------|------|
| 地図ドラッグ | オートズーム30秒停止 → 自動再開 |
| 道の駅ピンタップ | 道の駅詳細シート表示 |
| 広域ボタン | 短辺120kmにズーム |
| 詳細ボタン | 短辺300mにズーム |
| 目的地ボタン | 道の駅/RVパーク選択メニュー表示 |
| POIタップ | 詳細カード表示（Google Maps SDK標準） |

### 6-2. 道の駅詳細シート

iOS版: `MichiNavi/Features/StationDetail/StationDetailView.swift`

**表示内容:**
- 写真（imageUrl から非同期ロード）
- 道の駅名（タイトル）
- 距離・方角（例: "1.2 km · NE"）
- 路線名・所在地（都道府県 + 市町村）
- 施設設備グリッド（features キーからアイコン表示）
- 公式サイトリンク（外部ブラウザで開く）
- Apple Maps でナビ開始ボタン → Android版はGoogle Mapsインテント

**Google Maps ナビ起動インテント:**

```kotlin
val intent = Intent(Intent.ACTION_VIEW).apply {
    data = Uri.parse(
        "google.navigation:q=${station.latitude},${station.longitude}&mode=d"
    )
    setPackage("com.google.android.apps.maps")
}
startActivity(intent)
```

### 6-3. 道の駅選択画面（3階層ナビゲーション）

iOS版: `MichiNavi/Features/Destination/DestinationPickerView.swift`

**ナビゲーション階層:**

```
地方選択（8地方）
└── 都道府県選択
    └── 市町村選択（該当件数表示）
        └── 道の駅リスト
            └── 道の駅詳細（ナビ開始）
```

**8地方分類:**

| 地方 | 都道府県 |
|------|---------|
| 北海道 | 北海道 |
| 東北 | 青森県、岩手県、宮城県、秋田県、山形県、福島県 |
| 関東 | 茨城県、栃木県、群馬県、埼玉県、千葉県、東京都、神奈川県 |
| 中部 | 新潟県、富山県、石川県、福井県、山梨県、長野県、岐阜県、静岡県、愛知県 |
| 近畿 | 三重県、滋賀県、京都府、大阪府、兵庫県、奈良県、和歌山県 |
| 中国 | 鳥取県、島根県、岡山県、広島県、山口県 |
| 四国 | 徳島県、香川県、愛媛県、高知県 |
| 九州・沖縄 | 福岡県、佐賀県、長崎県、熊本県、大分県、宮崎県、鹿児島県、沖縄県 |

### 6-4. 設定画面

iOS版: `MichiNavi/Features/Settings/SettingsView.swift`

**設定項目:**

1. **地図上に表示する施設** — POIトグル5件（GS/コンビニ/レストラン/駐車場/RVパーク）
2. **ズームボタン位置** — 左 / 右（セグメント選択）
3. **クレジット** — Flaticon帰属表示リンク
   - URL: `https://www.flaticon.com/free-icons/navigation`
   - テキスト: `Navigation icons by ChilliColor - Flaticon`

---

## 7. 定数値一覧

```kotlin
// ズーム
const val WIDE_ZOOM_DEGREES   = 1.08    // 120km × 0.009
const val DETAIL_ZOOM_DEGREES = 0.0027  // 0.3km × 0.009

// 位置情報更新
const val LOCATION_INTERVAL_MS     = 500L   // 0.5秒
const val DISTANCE_FILTER_METERS   = 5f     // 5m
const val HEADING_FILTER_DEGREES   = 5f     // 5°

// 道の駅検索
const val STATION_SEARCH_INTERVAL_SEC = 5   // 5秒ごと
const val DEFAULT_SEARCH_RADIUS_KM    = 120 // CarPlay・リスト表示用
const val MAX_NEARBY_RESULTS          = 10  // リスト最大件数

// 速度判定
const val DRIVING_SPEED_THRESHOLD_KMH = 5.0  // 走行中判定

// 前方判定
const val AHEAD_THRESHOLD_DEGREES = 45.0    // 前方±45°

// オートズーム
const val AUTO_ZOOM_RESUME_SEC     = 30     // 手動操作後の再開待機時間
const val AUTO_ZOOM_CHANGE_RATE    = 0.3    // 速度変化30%以上でズーム更新
```

---

## 8. 未実装機能（将来対応）

### Android Auto 対応

iOS版の CarPlay 相当。別途 Android Auto アプリとして開発が必要。

- **使用テンプレート相当:**
  - `PlaceListMapTemplate` — POI一覧（CarPlayの `CPPointOfInterestTemplate` 相当）
  - `ListTemplate` — 道の駅リスト
  - `MessageTemplate` — ドライブ情報
- **申請:** Google Android Auto App Quality を参照

### 気象情報

iOS版では WeatherKit を使用予定（未実装）。Android版では以下を検討:

- OpenWeatherMap API（無料枠あり）
- OpenMeteo API（無料・登録不要）

### RVパーク自前データ

JRVA（日本RV協会）にデータ利用を問合せ中。回答があれば約608件のJSONデータを追加予定。
OpenStreetMapからの抽出（caravan_site: 276件）も選択肢として検討済み（ODbLライセンス要帰属表示）。

---

## 9. iOS版リポジトリ情報

```
リポジトリ: https://github.com/osprey74/michi-navi
ブランチ:   main
最終コミット: f731b99
```

**流用可能なファイル:**

| ファイル | 用途 |
|---------|------|
| `MichiNavi/MichiNavi/Resources/roadside_stations.json` | 道の駅データ（そのまま使用可） |
| `MichiNavi/Shared/Services/GeoUtils.swift` | 計算ロジックの参考実装 |
| `docs/screenshots/` | UIデザイン参考 |

---

## 10. ライセンス・クレジット

| 項目 | 内容 |
|------|------|
| アプリライセンス | MIT License © 2026 osprey74 |
| アプリアイコン | Navigation icons by ChilliColor - Flaticon |
| 道の駅データ | 国土交通省 公開データ（政府標準利用規約） |
| RVパーク・キャンプ場 | MapKit標準POI（暫定） / 将来: JRVA提供データ予定 |
