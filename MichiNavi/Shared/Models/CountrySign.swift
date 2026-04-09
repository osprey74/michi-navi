import Foundation
import CoreLocation

/// 北海道カントリーサイン + 市町村情報を統合したモデル
/// hokkaido_country_signs.json と hokkaido_municipalities.json を結合して生成
struct CountrySign: Identifiable, Sendable {

    /// 市町村コード（JIS 5桁）例: "01564" — ID として使用
    let id: String

    // MARK: - 市町村情報（hokkaido_municipalities.json より）

    let name: String                    // "大空町"
    let nameKana: String                // "おおぞらちょう"
    let subprefecture: String           // "網走" (振興局名)
    let subprefectureOffice: String     // "オホーツク総合振興局"
    let municipalityType: String        // "町"
    let population: Int?
    let populationYear: Int?
    let areaSqKm: Double?
    let centroid: CLLocationCoordinate2D  // 市町村重心（地図ピン配置用）
    let flower: FlowerInfo?
    let tourismUrl: String?
    let tourismSiteName: String?
    let officeCoordinate: CLLocationCoordinate2D?  // 市役所・役場の座標

    // MARK: - カントリーサイン情報（hokkaido_country_signs.json より）

    let signCoordinate: CLLocationCoordinate2D  // カントリーサイン設置推奨座標
    let imageName: String?              // Assets 画像名 "cs_01564"（なければ nil）
    let imageUrl: String?
    let imageCredit: String?
    let originText: String?             // 由来テキスト
    let designDescription: String?      // デザインのモチーフ

    /// 地図ピンに使用する座標（市町村重心）
    var coordinate: CLLocationCoordinate2D { centroid }
}

// MARK: - Hashable（.sheet(item:) 用）

extension CountrySign: Hashable {
    static func == (lhs: CountrySign, rhs: CountrySign) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - FlowerInfo

/// 市町村の花情報
struct FlowerInfo: Sendable {
    let name: String
    let description: String?
    let colorHex: String?
    let colorVibrantHex: String?
}
