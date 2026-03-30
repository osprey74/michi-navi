import Foundation

/// 地図タイルの種類
enum MapTileType: String, CaseIterable {
    case appleMaps = "appleMaps"        // デフォルト（ネイティブ、最速）
    case gsiPale = "gsiPale"
    case gsiStandard = "gsiStandard"
    case gsiSatellite = "gsiSatellite"
    case googleMaps = "googleMaps"

    var label: String {
        switch self {
        case .appleMaps:    return "Apple Maps"
        case .gsiPale:      return "国土地理院（淡色）"
        case .gsiStandard:  return "国土地理院（通常色）"
        case .gsiSatellite: return "国土地理院（衛星写真）"
        case .googleMaps:   return "Google Maps"
        }
    }

    /// MKTileOverlay 用 URL テンプレート（{z}/{x}/{y} プレースホルダ）
    /// Apple Maps と Google Maps はカスタムオーバーレイなし / 別途処理
    var tileURLTemplate: String {
        switch self {
        case .appleMaps:    return ""  // ネイティブ MKMapView を使用
        case .gsiPale:      return "https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png"
        case .gsiStandard:  return "https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png"
        case .gsiSatellite: return "https://cyberjapandata.gsi.go.jp/xyz/seamlessphoto/{z}/{x}/{y}.jpg"
        case .googleMaps:   return ""  // GoogleMapsTileOverlay で処理
        }
    }

    var isAppleMaps: Bool { self == .appleMaps }
    var isGoogleMaps: Bool { self == .googleMaps }
}
