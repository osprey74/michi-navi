import Foundation
import MapKit
import CoreLocation
import Observation

/// カントリーサインデータと市町村境界を管理するサービス
@Observable
final class CountrySignService {

    // MARK: - Published State

    /// 全カントリーサイン（市町村コード順）
    private(set) var allSigns: [CountrySign] = []

    /// GeoJSON から生成した市町村境界オーバーレイ（MKPolygon / MKMultiPolygon）
    private(set) var boundaryOverlays: [MKOverlay] = []

    private(set) var isLoaded = false

    // MARK: - Data Loading

    func loadData() {
        guard !isLoaded else { return }
        loadCountrySigns()
        loadBoundaries()
        isLoaded = true
    }

    private func loadCountrySigns() {
        guard
            let signsURL = Bundle.main.url(forResource: "hokkaido_country_signs", withExtension: "json"),
            let munisURL = Bundle.main.url(forResource: "hokkaido_municipalities", withExtension: "json")
        else { return }

        do {
            let signsData = try Data(contentsOf: signsURL)
            let munisData = try Data(contentsOf: munisURL)

            let decoder = JSONDecoder()
            let rawSigns = try decoder.decode([RawCountrySign].self, from: signsData)
            let rawMunis = try decoder.decode([RawMunicipality].self, from: munisData)

            let muniMap = Dictionary(rawMunis.map { ($0.code, $0) }, uniquingKeysWith: { _, last in last })

            allSigns = rawSigns.compactMap { raw in
                guard let muni = muniMap[raw.municipalityCode] else { return nil }
                return CountrySign(
                    id: raw.municipalityCode,
                    name: muni.name,
                    nameKana: muni.nameKana ?? "",
                    subprefecture: muni.subprefecture,
                    subprefectureOffice: muni.subprefectureOffice ?? muni.subprefecture,
                    municipalityType: muni.municipalityType ?? "",
                    population: muni.population,
                    populationYear: muni.populationYear,
                    areaSqKm: muni.areaSqKm,
                    centroid: CLLocationCoordinate2D(
                        latitude: muni.centroid.lat,
                        longitude: muni.centroid.lng
                    ),
                    flower: muni.flower.map {
                        FlowerInfo(
                            name: $0.name,
                            description: $0.description,
                            colorHex: $0.colorHex,
                            colorVibrantHex: $0.colorVibrantHex
                        )
                    },
                    tourismUrl: muni.tourismUrl,
                    tourismSiteName: muni.tourismSiteName,
                    officeCoordinate: muni.officeCoordinate.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    },
                    signCoordinate: CLLocationCoordinate2D(
                        latitude: raw.coordinate.lat,
                        longitude: raw.coordinate.lng
                    ),
                    imageName: raw.imageName,
                    imageUrl: raw.imageUrl,
                    imageCredit: raw.imageCredit,
                    originText: raw.originText,
                    designDescription: raw.designDescription
                )
            }.sorted { $0.id < $1.id }

        } catch {
            // データロード失敗時はサイレントに空リストのまま
        }
    }

    private func loadBoundaries() {
        guard let url = Bundle.main.url(forResource: "hokkaido_boundaries_simplified", withExtension: "geojson") else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = MKGeoJSONDecoder()
            let objects = try decoder.decode(data)

            var overlays: [MKOverlay] = []

            for case let feature as MKGeoJSONFeature in objects {
                // properties から code・name を取得
                var code = ""
                var muniName = ""
                if let propData = feature.properties,
                   let props = try? JSONDecoder().decode([String: String].self, from: propData) {
                    code = props["code"] ?? ""
                    muniName = props["name"] ?? ""
                }

                for geometry in feature.geometry {
                    // MKMultiPolygon はそのまま保持（個別展開しない）
                    if let multi = geometry as? MKMultiPolygon {
                        multi.title = code
                        multi.subtitle = muniName
                        overlays.append(multi)
                    } else if let polygon = geometry as? MKPolygon {
                        polygon.title = code
                        polygon.subtitle = muniName
                        overlays.append(polygon)
                    }
                }
            }

            boundaryOverlays = overlays

        } catch {
            // GeoJSON パース失敗時はサイレントに空配列のまま
        }
    }

    // MARK: - Queries

    /// 管内別グループ（北海道14振興局の定義順）
    var signsBySubprefecture: [(office: String, signs: [CountrySign])] {
        let grouped = Dictionary(grouping: allSigns, by: { $0.subprefectureOffice })
        return Self.subprefectureOrder
            .compactMap { office -> (office: String, signs: [CountrySign])? in
                guard let signs = grouped[office], !signs.isEmpty else { return nil }
                return (office: office, signs: signs.sorted { $0.name < $1.name })
            }
    }

    /// 管内の定義順序（北海道14振興局）
    static let subprefectureOrder: [String] = [
        "石狩振興局",
        "空知総合振興局",
        "後志総合振興局",
        "胆振総合振興局",
        "日高振興局",
        "渡島総合振興局",
        "檜山振興局",
        "上川総合振興局",
        "留萌振興局",
        "宗谷総合振興局",
        "オホーツク総合振興局",
        "十勝総合振興局",
        "釧路総合振興局",
        "根室振興局"
    ]

    /// 市町村コードでカントリーサインを取得
    func sign(byCode code: String) -> CountrySign? {
        allSigns.first { $0.id == code }
    }
}

// MARK: - Private Codable types for JSON decoding

private struct RawCountrySign: Codable {
    let municipalityCode: String
    let coordinate: RawCoordinate
    let imageName: String?
    let imageUrl: String?
    let imageCredit: String?
    let originText: String?
    let designDescription: String?
}

private struct RawMunicipality: Codable {
    let code: String
    let name: String
    let nameKana: String?
    let subprefecture: String
    let subprefectureOffice: String?
    let municipalityType: String?
    let population: Int?
    let populationYear: Int?
    let areaSqKm: Double?
    let centroid: RawCoordinate
    let flower: RawFlower?
    let tourismUrl: String?
    let tourismSiteName: String?
    let officeCoordinate: RawCoordinate?
}

private struct RawCoordinate: Codable {
    let lat: Double
    let lng: Double
}

private struct RawFlower: Codable {
    let name: String
    let description: String?
    let colorHex: String?
    let colorVibrantHex: String?
}
