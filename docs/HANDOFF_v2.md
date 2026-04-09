# HANDOFF v2.x — Michi-Navi カントリーサイン機能

> **作成日**: 2026-04-09
> **対象バージョン**: v2.x（App Store 申請予定）
> **ベースとなる Android 引き継ぎ資料**: `docs/android-handover.md`（v1.x 基礎機能）
> **iOS 最終コミット**: `29672ad`（main ブランチ）

このドキュメントは v2.x で追加・変更された機能を記述します。
v1.x（地図・道の駅・ナビ）は `docs/android-handover.md` を参照してください。

---

## 1. v2.x 追加機能 概要

| 機能 | 説明 |
|------|------|
| カントリーサイン地図表示 | 北海道 179 市町村のカントリーサインピンと市町村境界線を地図に表示 |
| カントリーサイン詳細 | 画像・デザイン由来・市町村情報・お気に入り・踏破管理 |
| カントリーサイン一覧 | お気に入り / 踏破済みリスト（タブ切替） |
| ランダムカードドロー | 未踏破サインをランダムに 1 枚引くカード表示 |
| 役場へナビ | カントリーサイン詳細から市役所・役場をナビ目的地に設定 |
| OS 共有シート | 道の駅・役場の位置情報をナビアプリ（NaviTime 等）に共有 |
| CS マーカー ON/OFF | 設定でカントリーサインマーカーを非表示にできる |

---

## 2. データモデル追加・変更

### 2-1. CountrySign（カントリーサイン統合モデル）

iOS 実装ファイル: `MichiNavi/Shared/Models/CountrySign.swift`

2 つの JSON（`hokkaido_country_signs.json` × `hokkaido_municipalities.json`）を
市町村コードで結合して生成するモデル。

```kotlin
data class CountrySign(
    val id: String,                      // 市町村コード（JIS 5桁）例: "01564"

    // hokkaido_municipalities.json より
    val name: String,                    // "大空町"
    val nameKana: String,                // "おおぞらちょう"
    val subprefecture: String,           // "網走"（振興局名省略形）
    val subprefectureOffice: String,     // "オホーツク総合振興局"
    val municipalityType: String,        // "町" / "市" / "村"
    val population: Int?,
    val populationYear: Int?,
    val areaSqKm: Double?,
    val centroid: LatLng,                // 市町村重心（地図ピン配置用）
    val flower: FlowerInfo?,
    val tourismUrl: String?,
    val tourismSiteName: String?,
    val officeCoordinate: LatLng?,       // 市役所・役場の座標 ← v2.x で追加

    // hokkaido_country_signs.json より
    val signCoordinate: LatLng,          // カントリーサイン設置推奨座標
    val imageName: String?,              // 画像ファイル名 "cs_01564"（拡張子なし）
    val imageUrl: String?,
    val imageCredit: String?,
    val originText: String?,             // 由来テキスト
    val designDescription: String?,      // デザインのモチーフ説明
) {
    // 地図ピンは市町村重心を使用
    val coordinate: LatLng get() = centroid
}

data class FlowerInfo(
    val name: String,
    val description: String?,
    val colorHex: String?,
    val colorVibrantHex: String?
)
```

### 2-2. AppSettings 追加項目

iOS 実装ファイル: `MichiNavi/Shared/Models/AppSettings.swift`

DataStore Preferences（Android）に追加が必要なキー:

| キー | 型 | デフォルト | 説明 |
|------|----|---------|------|
| `favorite_sign_ids` | `Set<String>` | `{}` | お気に入りカントリーサインのIDセット |
| `visited_sign_ids` | `Set<String>` | `{}` | 踏破済みカントリーサインのIDセット |
| `show_country_sign_markers` | `Boolean` | `true` | 地図上にCSマーカーを表示するか |

**注意**: `mapFocusSign`（選択中CS）はUI状態（ViewModel）に持ち、永続化しない。

---

## 3. JSON データファイル

### 3-1. hokkaido_municipalities.json

iOS 配置: `MichiNavi/MichiNavi/Resources/hokkaido_municipalities.json`
Android 推奨: `app/src/main/assets/hokkaido_municipalities.json`

**スキーマ（1件）:**

```json
{
  "code": "01564",
  "name": "大空町",
  "nameKana": "おおぞらちょう",
  "subprefecture": "網走",
  "subprefectureOffice": "オホーツク総合振興局",
  "municipalityType": "町",
  "population": 9547,
  "populationYear": 2020,
  "areaSqKm": 490.33,
  "centroid": { "lat": 44.0088, "lng": 144.1627 },
  "flower": {
    "name": "エゾヤマツツジ",
    "description": "春に咲く山のツツジ",
    "colorHex": "#E8625A",
    "colorVibrantHex": "#E8625A"
  },
  "tourismUrl": "https://...",
  "tourismSiteName": "大空町観光情報",
  "officeCoordinate": { "lat": 44.0234, "lng": 144.2089 }
}
```

**全件数: 179件（北海道全市町村）**

`officeCoordinate` は v2.x で追加したフィールド。データソース: 北海道開発局。**全 179 件すべてに値あり**。

### 3-2. hokkaido_country_signs.json

iOS 配置: `MichiNavi/MichiNavi/Resources/hokkaido_country_signs.json`
Android 推奨: `app/src/main/assets/hokkaido_country_signs.json`

**スキーマ（1件）:**

```json
{
  "municipalityCode": "01564",
  "coordinate": { "lat": 44.0123, "lng": 144.2001 },
  "imageName": "cs_01564",
  "imageUrl": null,
  "imageCredit": "北海道開発局（利用許諾済み）",
  "originText": "...",
  "designDescription": "..."
}
```

**全件数: 179件**

### 3-3. 市町村境界線 GeoJSON

iOS 配置: `MichiNavi/MichiNavi/Resources/hokkaido_boundaries_simplified.geojson`
Android 推奨: `app/src/main/assets/hokkaido_boundaries_simplified.geojson`

GeoJSON Feature Collection。各 Feature の `properties` に `code`（市町村コード）と `name` がある。
Geometry は `Polygon` または `MultiPolygon`。

---

## 4. カントリーサイン画像

iOS 配置: `MichiNavi/MichiNavi/CountrySigns/cs_{code}.jpg`
Android 推奨: `app/src/main/assets/country_signs/cs_{code}.jpg`

- ファイル名: `cs_01100.jpg`（5桁コード）
- 形式: JPEG
- 179件のうち画像提供済みは 170件程度（残りは「画像準備中」プレースホルダーを表示）

**画像の読み込み方（iOS の実装パターン）:**

```kotlin
// Android: Assets から読み込み
fun loadSignImage(context: Context, imageName: String): Bitmap? {
    return try {
        context.assets.open("country_signs/$imageName.jpg").use {
            BitmapFactory.decodeStream(it)
        }
    } catch (e: IOException) {
        null  // 画像なし → プレースホルダー表示
    }
}
```

---

## 5. 地図表示

### 5-1. カントリーサインマーカー

iOS 実装: `MichiNavi/Features/Map/CustomMapView.swift`

```kotlin
// マーカー仕様
// アイコン: pentagon（五角形）＋ 市町村の花の色または管内色
// 踏破済み: amber (#F09D26)
// 未踏破:   gray  (#8E8E93)
// お気に入り: ハートバッジを追加

fun createCountrySignMarker(sign: CountrySign, isVisited: Boolean, isFavorite: Boolean): MarkerOptions {
    val color = if (isVisited) Color.parseColor("#F09D26") else Color.GRAY
    return MarkerOptions()
        .position(LatLng(sign.centroid.lat, sign.centroid.lng))
        .title(sign.name)
        .icon(BitmapDescriptorFactory.fromBitmap(createPentagonIcon(color, isFavorite)))
}
```

### 5-2. 市町村境界線オーバーレイ

```kotlin
// 赤の点線スタイル
fun applyBoundaryStyle(polygon: Polygon) {
    polygon.strokeColor = Color.argb(178, 255, 59, 48)  // #FF3B30 70%透明度
    polygon.strokeWidth = 1.5f
    polygon.fillColor = Color.TRANSPARENT
    // 点線は Google Maps SDK では PathEffect 非対応
    // → 細い実線（strokeWidth: 1.5f）で代替
}
```

**注意**: Google Maps SDK for Android はポリゴン境界線の点線スタイルをネイティブサポートしていません。細い実線で代替するか、Canvas を使ったカスタムオーバーレイを検討してください。

### 5-3. CS マーカー ON/OFF

設定 `show_country_sign_markers` が `false` の場合:
- 地図上のCSマーカーと境界線オーバーレイを非表示にする
- リスト画面でカントリーサインタブを非表示にし、道の駅タブのみ表示する

---

## 6. 画面仕様

### 6-1. カントリーサイン詳細画面

iOS 実装: `MichiNavi/Features/CountrySign/CountrySignDetailView.swift`

**表示要素（上から順）:**

```
┌──────────────────────────────────┐
│  カントリーサイン画像（高さ 220pt） │
├──────────────────────────────────┤
│  [♥ お気に入り]  [✓ 踏破済み]     │  ← HStack、各ボタン均等幅
├──────────────────────────────────┤
│  カントリーサインについて            │
│    大空町（おおぞらちょう）          │
│    デザイン: ○○○               │
│    由来: ○○○○○○○            │
├──────────────────────────────────┤
│  市町村情報                        │
│    管内: オホーツク総合振興局        │
│    種別: 町                       │
│    人口: 9,547 人（2020年）        │
│    面積: 490.33 km²              │
├──────────────────────────────────┤
│  市町村の花（ある場合）              │
│    ● エゾヤマツツジ                │
├──────────────────────────────────┤
│  [→ 大空町へ行く  ] [↑]           │  ← ナビボタン + 共有ボタン
├──────────────────────────────────┤
│  公式サイト                        │
│    大空町観光情報 ↗               │
└──────────────────────────────────┘
```

**ナビボタン + 共有ボタン（ナビセクション）:**

- 「（市町村名）へ行く」: `officeCoordinate` がある場合のみ表示（全 179 件あり）
  - タップ → ナビアプリ選択ダイアログ（後述）
- 共有ボタン（`↑` アイコン）: OS 共有シートを開く（後述）

**お気に入り / 踏破ボタンの状態（道の駅詳細・CS詳細 共通）:**

| 状態 | 色 | アイコン | テキスト |
|------|----|---------|--------|
| お気に入りなし | グレー | `heart` | "お気に入り" |
| お気に入り済み | 赤 | `heart.fill` | "お気に入り済み" |
| 未踏破 | グレー | `checkmark.seal` | "踏破済み" |
| 踏破済み | 青 | `checkmark.seal.fill` | "踏破済み" |

> **注意:** 未踏破・踏破済みは同じテキスト "踏破済み" を表示し、アイコン（seal / seal.fill）と色（グレー / 青）で状態を区別する。

**画面表示時の副作用:** `mapFocusSign = sign` をセットし、地図をそのサインの位置に移動させる。

### 6-2. カントリーサインリスト画面

iOS 実装: `MichiNavi/Features/CountrySign/CountrySignListsView.swift`

**タブ構成（下部タブ）:**

| タブ | アイコン | コンテンツ |
|------|---------|---------|
| すべて | `map` | 振興局別グループリスト（14振興局） |
| お気に入り | `heart.fill` | お気に入りIDでフィルタ |
| 踏破済み | `checkmark.seal.fill` | 踏破IDでフィルタ |

**空状態メッセージ:**

| タブ | タイトル | アイコン | 説明文 |
|------|---------|---------|--------|
| お気に入り | "お気に入りなし" | `heart` | "詳細画面でハートボタンをタップすると追加されます" |
| 踏破済み | "踏破記録なし" | `checkmark.seal` | "詳細画面でチェックボタンをタップすると追加されます" |

**振興局（管内）の表示順序（すべてタブ）:**

```kotlin
val SUBPREFECTURE_ORDER = listOf(
    "石狩振興局", "空知総合振興局", "後志総合振興局", "胆振総合振興局",
    "日高振興局", "渡島総合振興局", "檜山振興局", "上川総合振興局",
    "留萌振興局", "宗谷総合振興局", "オホーツク総合振興局",
    "十勝総合振興局", "釧路総合振興局", "根室振興局"
)
```

### 6-3. ランダムカードドロー

iOS 実装: `MichiNavi/Features/CountrySign/RandomSignCardView.swift`

**トリガー:** カントリーサインリスト画面のツールバーに「`square.stack`（Stacks）」アイコンボタンを配置。CSマーカーON時のみ表示。

**カード画面レイアウト:**

```
┌──────────────────────────────────┐
│                             ✕    │  ← 閉じるボタン
│                                  │
│   ┌──────────────────────────┐   │
│   │                          │   │
│   │  カントリーサイン画像        │   │  ← AspectFit、角丸、影付き
│   │  （大きく表示）             │   │
│   │                          │   │
│   └──────────────────────────┘   │
│                                  │
│       [地図で見る]   [詳細 →]     │
│         [🃏 もう一度引く]         │
└──────────────────────────────────┘
```

**ランダム選択ロジック:**

```kotlin
fun drawRandomSign(
    allSigns: List<CountrySign>,
    visitedIds: Set<String>
): CountrySign? {
    return allSigns.filter { it.id !in visitedIds }.randomOrNull()
}
```

**全踏破時（未踏破 = 0件）:** 空状態ビューを表示。
- アイコン: `trophy.fill`（または相当）
- タイトル: "全179市町村を踏破しました！"
- 説明文: "北海道全市町村のカントリーサインを踏破しました。おめでとうございます！"

**「地図で見る」ボタンの動作:**
1. `mapFocusSign = drawnSign` をセット
2. カードシートを閉じる
3. リストシートも閉じる
4. 結果として地図画面でそのサインにフォーカスが移動する

**「詳細」ボタンの動作:** カントリーサイン詳細画面へ遷移（モーダル上で Push 遷移）

**「もう一度引く」ボタン:** 再度ランダム選択・アニメーション再生

---

## 7. ナビゲーション（外部アプリ連携）

### 7-1. 道の駅・役場へのナビ起動（選択ダイアログ）

iOS 実装: `MichiNavi/Shared/Services/NavigationService.swift`

**対応ナビアプリ:**

| アプリ | iOS（URL スキーム） | Android（Intent） |
|--------|-----------------|-----------------|
| Apple Maps | `MKMapItem.openInMaps()` | 非対応（Google Maps で代替） |
| Google Maps | `comgooglemaps://?daddr=lat,lng` | `google.navigation:q=lat,lng&mode=d` |
| Yahoo!カーナビ | `yjcarnavi://navi/select?lat=&lon=&name=` | `jp.co.yahoo.android.apps.navi` Intent |
| Waze | `waze://?ll=lat,lng&navigate=yes` | `waze://` または Waze Deep Link |

**Android 実装例（Google Maps）:**

```kotlin
fun navigateToGoogleMaps(lat: Double, lng: Double, name: String) {
    val uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        setPackage("com.google.android.apps.maps")
    }
    if (intent.resolveActivity(packageManager) != null) {
        startActivity(intent)
    }
}
```

**Android 実装例（Yahoo!カーナビ）:**

```kotlin
fun navigateToYahooCarNavi(lat: Double, lng: Double, name: String) {
    val encoded = URLEncoder.encode(name, "UTF-8")
    val uri = Uri.parse("yjcarnavi://navi/select?lat=$lat&lon=$lng&name=$encoded")
    val intent = Intent(Intent.ACTION_VIEW, uri)
    if (intent.resolveActivity(packageManager) != null) {
        startActivity(intent)
    }
}
```

**Android 実装例（Waze）:**

```kotlin
fun navigateToWaze(lat: Double, lng: Double) {
    val uri = Uri.parse("waze://?ll=$lat,$lng&navigate=yes")
    val intent = Intent(Intent.ACTION_VIEW, uri)
    if (intent.resolveActivity(packageManager) != null) {
        startActivity(intent)
    }
}
```

**アプリ検出:** `packageManager.getLaunchIntentForPackage(packageName) != null` でインストール確認。Google Maps は常に表示（デフォルト地図アプリとして）。

### 7-2. OS 共有シート（NaviTime などカスタム URL 非公開アプリ向け）

iOS 実装: `MichiNavi/Shared/LocationShareSheet.swift`

iOS では `UIActivityViewController` に `MKMapItem` + Apple Maps URL を渡すことで、
NaviTime などの共有拡張経由でナビアプリに位置情報を送れる。

**Android 実装:**

```kotlin
fun shareLocation(lat: Double, lng: Double, name: String) {
    val encoded = URLEncoder.encode(name, "UTF-8")

    // Apple Maps URL（NaviTime など URL 共有拡張を持つアプリ向け）
    val mapsUrl = "https://maps.apple.com/?ll=$lat,$lng&q=$encoded"

    // Google Maps URL（Android 向けにより適切）
    val googleMapsUrl = "https://www.google.com/maps?q=$lat,$lng"

    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, googleMapsUrl)
        putExtra(Intent.EXTRA_SUBJECT, name)
    }
    startActivity(Intent.createChooser(intent, "共有"))
}
```

**注意:** Android の `ACTION_SEND` + `text/plain` で Google Maps URL を渡すと、
NaviTime などの共有先でその URL から目的地が自動設定されます。

---

## 8. 設定画面 追加項目

iOS 実装: `MichiNavi/Features/Settings/SettingsView.swift`

### カントリーサイン関連トグル

```
── カントリーサイン ──────────────
地図にマーカーを表示    [ON/OFF トグル]
```

`show_country_sign_markers` を DataStore Preferences で管理。

### クレジット追加

v2.x で以下のクレジットを追加:

```
── データ出典 ─────────────────────
カントリーサイン画像
  北海道開発局（利用許諾済み）
  大空町・本別町・今金町（個別利用許諾済み）

道の駅データ
  一般社団法人 全国道の駅連絡会（利用許諾済み）
```

---

## 9. 用語統一

v2.x で iOS 内の表記を統一しました。Android 版でも同一表記を使用してください。

| 旧表記 | 新表記 | 説明 |
|--------|--------|------|
| 到達 | **踏破** | CS・道の駅に実際に行った記録 |
| 到達済み | **踏破済み** | リスト・ボタンラベル |
| 到達記録 | **踏破記録** | 空状態タイトル |

---

## 10. Android 実装上の注意事項

### 境界線の点線スタイル

Google Maps SDK for Android はポリゴンの境界線に点線スタイルを直接指定できません。
選択肢:
1. 細い実線（`strokeWidth: 2f`）で代替 ← 推奨
2. `TileOverlay` でカスタム描画
3. Mapbox SDK に移行（点線サポートあり）

### 振興局グループ化

`CountrySign.subprefectureOffice` でグループ化し、`SUBPREFECTURE_ORDER` の順序で表示。
グループ内はアルファベット（または五十音）でソート。

### 画像の遅延読み込み

カントリーサイン画像は Bundle 内の JPEG ファイル。Coil または Glide で読み込み可。
`imageName` が `null` の場合はプレースホルダー（`signpost.right` 相当）を表示。

```kotlin
// Coil の場合
AsyncImage(
    model = ImageRequest.Builder(context)
        .data(context.assets.open("country_signs/${sign.imageName}.jpg"))
        .crossfade(true)
        .build(),
    contentDescription = sign.name,
    error = painterResource(R.drawable.ic_signpost)
)
```

### 役場座標（officeCoordinate）

`hokkaido_municipalities.json` に `officeCoordinate: { lat, lng }` を追加済み。
**全 179 件すべてに値あり**。データソース: 北海道開発局（計測地点: 各市町村の役場）。

---

## 11. ファイル一覧（v2.x 新規・変更）

| ファイル | 種別 | 説明 |
|---------|------|------|
| `MichiNavi/Shared/Models/CountrySign.swift` | 新規 | CSモデル |
| `MichiNavi/Shared/Models/AppSettings.swift` | 変更 | CS関連設定追加 |
| `MichiNavi/Shared/Services/CountrySignService.swift` | 新規 | CSデータロード・境界線 |
| `MichiNavi/Shared/Services/NavigationService.swift` | 変更 | 座標指定ナビメソッド追加 |
| `MichiNavi/Shared/LocationShareSheet.swift` | 新規 | OS共有シートラッパー |
| `MichiNavi/Features/CountrySign/CountrySignDetailView.swift` | 新規 | CS詳細画面 |
| `MichiNavi/Features/CountrySign/CountrySignListsView.swift` | 新規 | CSリスト画面 |
| `MichiNavi/Features/CountrySign/RandomSignCardView.swift` | 新規 | ランダムカードドロー |
| `MichiNavi/Features/Map/ContentView.swift` | 変更 | CSマーカー切替・リスト統合 |
| `MichiNavi/Features/StationDetail/StationDetailView.swift` | 変更 | 共有ボタン追加・ボタン文言統一 |
| `MichiNavi/MichiNavi/Resources/hokkaido_municipalities.json` | 変更 | officeCoordinate 追加 |
| `MichiNavi/MichiNavi/Resources/hokkaido_country_signs.json` | 新規 | CSマスタ（179件） |
| `MichiNavi/MichiNavi/Resources/hokkaido_boundaries_simplified.geojson` | 新規 | 市町村境界線 |

---

*v2.0.0 リリース済み（2026-04-09）。最終コミット: `c20b991`（タグ: `v2.0.0`）*
