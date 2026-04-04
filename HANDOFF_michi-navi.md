# HANDOFF — Michi-Navi 新機能実装

> **作成日**: 2026-04-04
> **対象機能**: ①市町村の花表示 ②カントリーサインスタンプラリー ③道の駅フォトアルバム
> **プラットフォーム**: iOS (iPhone / iPad のみ、CarPlay対応不要)

---

## 0. 準備済みデータファイル一覧

| ファイル | 説明 | 件数 |
|---------|------|------|
| `municipalities/hokkaido_municipalities.json` | 北海道全179市区町村マスタ | 179件 |
| `municipalities/hokkaido_country_signs.json` | カントリーサインマスタ（座標・画像名） | 179件 |
| `schema/schema_definition.json` | 全データのJSONスキーマ定義 | — |
| `scripts/generate_municipality_master.py` | マスタJSON生成スクリプト | — |
| `scripts/preprocess_geojson.py` | GeoJSON前処理スクリプト（境界線データ） | — |

### 🔴 Claude Codeで着手前に必要な手動作業

1. **花の画像準備**（6件が未制定・要確認）
   - 未設定: `01333 知内町 / 01393 黒松内町 / 01396 真狩村 / 01404 神恵内村 / 01406 古平町 / 01585 安平町`
   - 画像は `Assets.xcassets/Flowers/flower_{code}.imageset` に配置

2. **GeoJSON取得**
   - [国土数値情報DLサービス](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2024.html) から北海道(01)のN03データをDL
   - `scripts/preprocess_geojson.py` を実行して `municipalities/hokkaido_boundaries_simplified.geojson` を生成

3. **カントリーサイン画像収集**（別途）
   - 各市区町村のカントリーサイン写真を撮影またはCC素材で収集
   - `Assets.xcassets/CountrySigns/cs_{code}.imageset` に配置

4. **観光サイト名補完**
   - `hokkaido_municipalities.json` の `tourismSiteName` フィールドが全件 `null`
   - 観光URLのあるものは表示名を補完すること

---

## 1. 機能①：市町村の花 表示

### 配置場所
道の駅詳細画面（`StationDetailView`）のフォトアルバムセクション直下に「○○町について」セクションを追加。

### UI仕様

```
────────────────────────────
[人口] [面積] [振興局]        ← 3カラム統計
────────────────────────────
[花の写真 64×64pt] 町の花
                 ハナミズキ
                 春の訪れを告げる花
────────────────────────────
[観光情報 →]                 ← URLがnullなら非表示 or グレーアウト
────────────────────────────
```

### データ取得ロジック

```swift
// 道の駅のmunicipalityCodeから市区町村情報を引く
func municipality(for station: MichiStation) -> Municipality? {
    return MunicipalityRepository.shared.find(code: station.municipalityCode)
}
```

### MunicipalityRepository (設計指針)

```swift
class MunicipalityRepository {
    static let shared = MunicipalityRepository()
    private var data: [String: Municipality] = [:]  // code -> Municipality

    init() {
        // Bundle内のhokkaido_municipalities.jsonをロード
        guard let url = Bundle.main.url(forResource: "hokkaido_municipalities", 
                                         withExtension: "json"),
              let json = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Municipality].self, from: json)
        else { return }
        data = Dictionary(uniqueKeysWithValues: list.map { ($0.code, $0) })
    }

    func find(code: String) -> Municipality? { data[code] }
}
```

### 観光情報リンクの開き方

```swift
// SafariViewControllerで開く（外部ブラウザ不使用）
if let urlString = municipality.tourismUrl,
   let url = URL(string: urlString) {
    let safari = SFSafariViewController(url: url)
    present(safari, animated: true)
}
```

### ピン色への花の色適用

```swift
// MKMarkerAnnotationView への適用
view.markerTintColor = station.municipalityFlowerColor ?? UIColor(named: "DefaultPinColor")

extension MichiStation {
    var municipalityFlowerColor: UIColor? {
        guard let hex = MunicipalityRepository.shared
                         .find(code: municipalityCode)?
                         .flower?.colorVibrantHex else { return nil }
        return UIColor(hex: hex)
    }
}
```

**注意**: `colorVibrantHex` は初期値 `null`。花画像から抽出後に補完する。
抽出方法は別途 `extract_flower_colors.py` を参照（未生成・必要に応じて作成）。

---

## 2. 機能②：カントリーサイン スタンプラリー

### 地図モード切り替え

```swift
enum MapMode { case michiStation, countrySign }

// トグルで切り替え
@Published var mapMode: MapMode = .michiStation

// モード変更時の処理
func switchMapMode(_ mode: MapMode) {
    mapMode = mode
    switch mode {
    case .michiStation:
        mapView.removeOverlays(boundaryOverlays)
        mapView.removeAnnotations(countrySignAnnotations)
        mapView.addAnnotations(stationAnnotations)
    case .countrySign:
        mapView.removeAnnotations(stationAnnotations)
        mapView.addOverlays(boundaryOverlays, level: .aboveRoads)
        mapView.addAnnotations(countrySignAnnotations)
    }
}
```

### 行政区域境界線の描画

```swift
// GeoJSONからMKPolygonOverlayを生成
func loadBoundaryOverlays() -> [MKPolygon] {
    guard let url = Bundle.main.url(forResource: "hokkaido_boundaries_simplified",
                                    withExtension: "geojson"),
          let data = try? Data(contentsOf: url),
          let geo = try? MKGeoJSONDecoder().decode(data)
    else { return [] }

    return geo.compactMap { obj -> MKPolygon? in
        (obj as? MKGeoJSONFeature)?.geometry.first as? MKPolygon
    }
}

// 赤の点線スタイル
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let polygon = overlay as? MKPolygon {
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.7)
        renderer.lineWidth = 1.5
        renderer.lineDashPattern = [4, 4]
        renderer.fillColor = .clear
        return renderer
    }
    return MKOverlayRenderer(overlay: overlay)
}
```

### カントリーサインアノテーション

```swift
class CountrySignAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var municipalityCode: String
    var isStamped: Bool  // 踏破済み
    var isFavorite: Bool
}

// マーカー表示（踏破済み=amber / 未踏破=gray）
func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let cs = annotation as? CountrySignAnnotation else { return nil }
    let view = MKMarkerAnnotationView(annotation: annotation,
                                      reuseIdentifier: "countrySign")
    view.markerTintColor = cs.isStamped
        ? UIColor(red: 0.94, green: 0.62, blue: 0.15, alpha: 1)  // amber
        : UIColor.systemGray
    view.glyphImage = UIImage(systemName: "pentagon.fill")
    return view
}
```

### GPSジオフェンス（バックグラウンド検知）

```swift
// Info.plist に追加必須:
// NSLocationAlwaysAndWhenInUseUsageDescription
// NSLocationWhenInUseUsageDescription
// UIBackgroundModes: location

func setupGeofences() {
    let radius: CLLocationDistance = 150  // 半径150m

    for sign in CountrySignRepository.shared.all where !sign.isStamped {
        let region = CLCircularRegion(
            center: sign.coordinate,
            radius: radius,
            identifier: sign.municipalityCode
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        locationManager.startMonitoring(for: region)
    }
}

func locationManager(_ manager: CLLocationManager,
                     didEnterRegion region: CLRegion) {
    guard let code = region.identifier as? String else { return }
    stampCountrySign(code: code)
    sendStampNotification(code: code)
}
```

**注意**: CLLocationManager のジオフェンスは同時登録上限20件。
179件全件を常時監視することはできないため、現在地周辺の未取得サインのみ
動的に登録・解除するロジックが必要。

```swift
// 現在地周辺のジオフェンスのみ登録（半径50km以内の未取得を最大20件）
func updateNearbyGeofences(currentLocation: CLLocation) {
    locationManager.monitoredRegions.forEach { locationManager.stopMonitoring(for: $0) }

    let nearby = CountrySignRepository.shared.all
        .filter { !$0.isStamped }
        .sorted { a, b in
            currentLocation.distance(from: CLLocation(latitude: a.coordinate.latitude,
                                                       longitude: a.coordinate.longitude))
            < currentLocation.distance(from: CLLocation(latitude: b.coordinate.latitude,
                                                         longitude: b.coordinate.longitude))
        }
        .prefix(20)

    for sign in nearby {
        let region = CLCircularRegion(center: sign.coordinate, radius: 150,
                                      identifier: sign.municipalityCode)
        region.notifyOnEntry = true
        locationManager.startMonitoring(for: region)
    }
}
```

### 詳細画面の仕様

| 要素 | 内容 |
|------|------|
| カントリーサイン画像 | `cs_{code}` のバンドル画像。上部に大きく表示 |
| 市区町村名 | `municipality.name` |
| 振興局名 | `municipality.subprefectureOffice` |
| 由来テキスト | `countrySign.originText`（null の場合は非表示） |
| お気に入りマーク | ★タップでトグル、CoreDataに保存 |
| 踏破済みマーク | ✓タップでトグル（手動設定）、GPS自動取得も同フラグ |
| 訪問写真 | 1枚のみ。フォトアルバムと同一UX（詳細は機能③参照） |
| 踏破証明ステータス | 写真あり→「踏破証明済み」/ 写真なし踏破→「踏破済み」/ 未踏→「未踏破」 |

### CoreData エンティティ

```
CountrySignRecord
  ├── municipalityCode: String (indexed)
  ├── isStamped: Bool
  ├── isFavorite: Bool
  ├── stampedAt: Date?          ← GPS自動取得日時
  ├── stampMethod: String?      ← "gps" | "manual"
  └── photoPath: String?        ← 踏破証明写真のパス
```

### コレクション一覧

- 踏破済み / お気に入りをセグメントコントロールで切り替え
- 各行: カントリーサイン画像（28×28pt） + 市区町村名 + 取得日 + ★
- 上部に北海道全体の進捗: `{stamped} / 179` + プログレスバー
- 写真証明済みはカメラアイコンを行末に表示

---

## 3. 機能③：道の駅フォトアルバム

### 配置場所
道の駅詳細画面の、施設基本情報（営業時間等）セクションの下。市町村情報セクションの上。

### UI仕様

```
─── フォトアルバム ────── 2/3枚 ──
[ 写真1 ]  [ 写真2 ]  [  +  ]
（正方形 各(screenWidth-44)/3 pt）
```

- タイル間マージン: 6pt
- 左右パディング: 12pt（画面端から）
- タイルサイズ: `(UIScreen.main.bounds.width - 12*2 - 6*2) / 3` (正方形)

### 操作仕様

| 操作 | 動作 |
|------|------|
| 空タイルをタップ | `PHPickerViewController` 起動（カメラ/ライブラリ選択） |
| 写真タイルをタップ | フルスクリーン表示（✕で閉じる、左右スワイプで移動） |
| 写真タイルをロングタップ | 削除確認ダイアログ表示 |
| フルスクリーン中ロングタップ | 同上 |

### 写真保存設計

```swift
// 保存パス: {appSandbox}/Library/Application Support/Albums/{stationId}/photo_{1-3}.jpg
func photoURL(stationId: String, index: Int) -> URL {
    let dir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Albums/\(stationId)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, 
                                              withIntermediateDirectories: true)
    return dir.appendingPathComponent("photo_\(index).jpg")
}

// 保存時リサイズ
func savePhoto(_ image: UIImage, stationId: String, index: Int) {
    let resized = image.resized(maxDimension: 1024)
    let data = resized.jpegData(compressionQuality: 0.72)
    try? data?.write(to: photoURL(stationId: stationId, index: index))
}
```

### CoreData エンティティ

```
StationPhotoRecord
  ├── stationId: String (indexed)
  ├── slot: Int16                ← 1〜3
  ├── photoPath: String
  └── createdAt: Date
```

### 必要な Info.plist キー

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>道の駅の思い出写真をアルバムに保存するために使用します。</string>
<key>NSCameraUsageDescription</key>
<string>道の駅で写真を撮影するために使用します。</string>
```

---

## 4. 共通：写真操作UX（機能②③共通）

```swift
// PHPickerViewController 起動
func presentPhotoPicker() {
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    present(picker, animated: true)
}

// 削除確認ダイアログ
func confirmDelete(onConfirm: @escaping () -> Void) {
    let alert = UIAlertController(title: "写真を削除しますか？",
                                   message: "この操作は元に戻せません",
                                   preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
    alert.addAction(UIAlertAction(title: "削除", style: .destructive) { _ in onConfirm() })
    present(alert, animated: true)
}
```

---

## 5. 依存ライブラリ・フレームワーク

| フレームワーク | 用途 |
|-------------|------|
| MapKit | 地図・アノテーション・オーバーレイ |
| CoreLocation | GPS・ジオフェンス |
| CoreData | スタンプ・写真メタデータの永続化 |
| PhotosUI (PHPickerViewController) | 写真選択 |
| SafariServices (SFSafariViewController) | 観光サイトリンク |
| UserNotifications | スタンプ取得プッシュ通知 |

外部ライブラリ追加不要。すべてApple標準フレームワークで実装可能。

---

## 6. データ精査 TODO（実装前に確認推奨）

- [ ] 花データ未設定6件（知内町・黒松内町・真狩村・神恵内村・古平町・安平町）の確認
- [ ] 座標 `approximate: true` の全129件を GeoJSON重心で上書き（`preprocess_geojson.py` 実行後）
- [ ] 観光URLの死活確認（特に小規模自治体のURL）
- [ ] `tourismSiteName` の全件補完
- [ ] 花の代表色（`colorHex` / `colorVibrantHex`）の抽出・補完
- [ ] カントリーサイン `originText` / `designDescription` の調査・記入

---

## 7. ファイル配置（Xcode プロジェクト）

```
michi-navi-ios/
├── Resources/
│   ├── hokkaido_municipalities.json    ← Bundle同梱
│   ├── hokkaido_country_signs.json     ← Bundle同梱
│   └── hokkaido_boundaries_simplified.geojson  ← Bundle同梱（GeoJSON前処理後）
├── Assets.xcassets/
│   ├── Flowers/
│   │   └── flower_{code}.imageset      ← 179件（手動追加）
│   └── CountrySigns/
│       └── cs_{code}.imageset          ← 179件（手動追加）
└── Sources/
    ├── Repository/
    │   ├── MunicipalityRepository.swift
    │   └── CountrySignRepository.swift
    ├── Models/ (CoreData)
    │   ├── CountrySignRecord+CoreData
    │   └── StationPhotoRecord+CoreData
    └── Views/
        ├── StationDetailView.swift      ← フォトアルバム・市町村情報追加
        ├── CountrySignMapView.swift     ← カントリーサインモード地図
        ├── CountrySignDetailView.swift  ← 詳細画面
        └── CollectionListView.swift    ← 踏破済み・お気に入り一覧
```

---

*このドキュメントは2026-04-04に生成されました。データ精査後に再生成してください。*
