import MapKit

/// Google Maps Tile API v1 用カスタムタイルオーバーレイ
/// セッショントークンの取得・キャッシュを内部で管理する
final class GoogleMapsTileOverlay: MKTileOverlay {

    private let apiKey: String
    private var sessionToken: String?
    private var sessionExpiry: Date = .distantPast
    private let lock = NSLock()

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // loadTile(at:result:) でオーバーライドするためここは使用しない
        URL(string: "about:blank")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        getSessionToken { [weak self] token in
            guard let self, let token else {
                result(nil, NSError(domain: "GoogleMapsTileOverlay", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "セッショントークンの取得に失敗しました"]))
                return
            }
            let urlStr = "https://tile.googleapis.com/v1/2dtiles/\(path.z)/\(path.x)/\(path.y)?session=\(token)&key=\(self.apiKey)"
            guard let url = URL(string: urlStr) else {
                result(nil, URLError(.badURL))
                return
            }
            URLSession.shared.dataTask(with: url) { data, _, error in
                result(data, error)
            }.resume()
        }
    }

    // MARK: - Session management

    private func getSessionToken(completion: @escaping (String?) -> Void) {
        lock.lock()
        let cachedToken = sessionToken
        let cachedExpiry = sessionExpiry
        lock.unlock()

        // セッションが有効（残り1時間以上）なら再利用
        if let token = cachedToken, !token.isEmpty,
           cachedExpiry > Date().addingTimeInterval(3600) {
            completion(token)
            return
        }

        createSession(completion: completion)
    }

    private func createSession(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://tile.googleapis.com/v1/createSession?key=\(apiKey)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["mapType": "roadmap", "language": "ja", "region": "JP"]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self,
                  let data,
                  error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["session"] as? String,
                  let expiryStr = json["expiry"] as? String,
                  let expiryTs = TimeInterval(expiryStr) else {
                completion(nil)
                return
            }

            self.lock.lock()
            self.sessionToken = token
            self.sessionExpiry = Date(timeIntervalSince1970: expiryTs)
            self.lock.unlock()

            completion(token)
        }.resume()
    }
}
