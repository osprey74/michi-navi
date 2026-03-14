import Foundation
import CoreLocation

/// 道の駅データの読み込みと検索を提供するサービス
@Observable
final class RoadsideStationService {

    /// 全道の駅データ
    private(set) var allStations: [RoadsideStation] = []

    /// 前方の道の駅（近い順、最大10件）— リストパネル用
    private(set) var nearbyStations: [NearbyStation] = []

    /// 検索範囲内の全道の駅（全方位）— 地図ピン用
    private(set) var stationsInRange: [NearbyStation] = []

    /// データ読み込み済みフラグ
    private(set) var isLoaded = false

    // MARK: - データ読み込み

    /// バンドル内の JSON から道の駅データを読み込む
    func loadStations() {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "roadside_stations", withExtension: "json") else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allStations = try JSONDecoder().decode([RoadsideStation].self, from: data)
            isLoaded = true
        } catch {
            print("[RoadsideStationService] JSON decode error: \(error)")
        }
    }

    // MARK: - 検索

    /// 現在地と進行方向から前方の道の駅を検索する
    /// - Parameters:
    ///   - location: 現在地
    ///   - heading: 進行方向 (0–360°)
    ///   - maxDistanceKm: 最大検索距離 (デフォルト 100km)
    ///   - maxResults: 最大件数 (デフォルト 10)
    /// 現在地と進行方向から道の駅を検索する
    /// - 走行中（速度 > 5 km/h）: 前方 ±45° のみ
    /// - 停車中: 全方位から近い順
    func updateNearbyStations(
        location: CLLocationCoordinate2D,
        heading: Double,
        speedKmh: Double = 0,
        maxDistanceKm: Double = 100,
        maxResults: Int = 10
    ) {
        guard isLoaded else { return }

        let isMoving = speedKmh > 5

        // 範囲内の全道の駅を計算（地図ピン用）
        let allInRange = allStations.compactMap { station -> NearbyStation? in
            let distance = GeoUtils.haversine(from: location, to: station.coordinate)
            guard distance <= maxDistanceKm else { return nil }
            let bearingToStation = GeoUtils.bearing(from: location, to: station.coordinate)
            return NearbyStation(
                station: station,
                distanceKm: distance,
                bearing: bearingToStation
            )
        }
        .sorted { $0.distanceKm < $1.distanceKm }

        stationsInRange = allInRange

        // リストパネル用: 走行中は前方のみ、最大件数制限
        if isMoving {
            nearbyStations = Array(allInRange.filter { nearby in
                GeoUtils.isAhead(heading: heading, bearingToTarget: nearby.bearing)
            }.prefix(maxResults))
        } else {
            nearbyStations = Array(allInRange.prefix(maxResults))
        }
    }

    // MARK: - 都道府県・市町村グループ化

    /// 標準47都道府県順
    static let prefectureOrder = [
        "北海道",
        "青森県","岩手県","宮城県","秋田県","山形県","福島県",
        "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県",
        "新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜県","静岡県","愛知県",
        "三重県","滋賀県","京都府","大阪府","兵庫県","奈良県","和歌山県",
        "鳥取県","島根県","岡山県","広島県","山口県",
        "徳島県","香川県","愛媛県","高知県",
        "福岡県","佐賀県","長崎県","熊本県","大分県","宮崎県","鹿児島県","沖縄県"
    ]

    /// データに存在する都道府県のみ返す（標準順）
    var availablePrefectures: [String] {
        let set = Set(allStations.compactMap { $0.prefecture })
        return Self.prefectureOrder.filter { set.contains($0) }
    }

    /// 指定都道府県の市町村リスト（重複排除・ソート済み）
    func municipalities(in prefecture: String) -> [String] {
        var seen = Set<String>()
        return allStations
            .filter { $0.prefecture == prefecture }
            .compactMap { $0.municipality }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    /// 指定都道府県（+ 任意で市町村）の道の駅リスト（名前順）
    func stations(in prefecture: String, municipality: String? = nil) -> [RoadsideStation] {
        allStations.filter { station in
            station.prefecture == prefecture &&
            (municipality == nil || station.municipality == municipality)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - 表示領域フィルタ

    /// 地図の表示領域内にある道の駅を返す（地図ピン用）
    private(set) var visibleStations: [RoadsideStation] = []

    /// 表示領域の矩形内にある道の駅でフィルタする
    func updateVisibleStations(
        center: CLLocationCoordinate2D,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) {
        guard isLoaded else { return }

        let minLat = center.latitude - latitudeDelta / 2
        let maxLat = center.latitude + latitudeDelta / 2
        let minLon = center.longitude - longitudeDelta / 2
        let maxLon = center.longitude + longitudeDelta / 2

        visibleStations = allStations.filter { station in
            station.latitude >= minLat && station.latitude <= maxLat &&
            station.longitude >= minLon && station.longitude <= maxLon
        }
    }
}
