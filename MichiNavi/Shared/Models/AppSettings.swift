import Foundation

/// アプリ全体の設定を管理する
/// UserDefaults に永続化し、@Observable で UI に反映
@Observable
final class AppSettings {

    /// ズームボタンの表示位置
    enum ZoomPosition: String, CaseIterable {
        case left = "left"
        case right = "right"

        var label: String {
            switch self {
            case .left: return "左側"
            case .right: return "右側"
            }
        }
    }

    /// ズームボタンの表示位置（デフォルト: 右側）
    var zoomPosition: ZoomPosition {
        didSet { save() }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "zoomPosition") ?? "right"
        self.zoomPosition = ZoomPosition(rawValue: stored) ?? .right
    }

    private func save() {
        UserDefaults.standard.set(zoomPosition.rawValue, forKey: "zoomPosition")
    }
}
