# Michi-navi タスク

## 進捗サマリー

完了 0 / 全 3

## iPadOS 27 リサイズ対応（2026-10-14 記録）

iPadOS 27 / iOS 27 SDK から `UIRequiresFullScreen` で全画面に固定できなくなります（[TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)）。Michi-navi はこのキーを使っておらず、launch screen あり・iPad の 4 方向対応済みのため、必須の改修はありません。以下は念のための確認と手入れです。

- [ ] iPad シミュレーター（iPadOS 27）でウィンドウを最小・縦長に細くし、メイン画面のレイアウトが崩れないか確認する
  - 右下のボタン列（44pt × 5 個、`Features/Map/ContentView.swift:175-222`）が、高さの低いウィンドウで上部の要素と重ならないか
  - `.presentationDetents([.medium, .large])` のシート（道の駅・カントリーサインの詳細）が細いウィンドウで使いやすいか
- [ ] `Features/Map/CustomMapView.swift` の `UIScreen.main.scale`（4 か所：58, 91, 205, 297 行）を `traitCollection.displayScale` などに置き換える（`UIScreen.main` は iOS 16 から非推奨。外部ディスプレイで倍率がずれる可能性への備え）
- [ ] iOS 27 SDK でビルドしたアプリの `Info.plist` に `UILaunchScreen` キーが入っていることを確認する（入っていないと ITMS-90870 でアップロードが拒否される。[TN3208](https://developer.apple.com/documentation/technotes/tn3208-preparing-your-apps-launch-screen-to-meet-app-store-requirements)）
