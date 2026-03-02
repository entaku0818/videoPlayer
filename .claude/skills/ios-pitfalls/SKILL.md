---
name: ios-pitfalls
description: このプロジェクトで実際に踏んだ iOS 開発の落とし穴と対策。CoreData, AVFoundation, AVAudioSession など。CoreData の設定変更・新機能追加・マイグレーション対応時に必ず参照すること。
metadata:
  author: Smart Player Team
  version: 1.0.0
  category: development
  tags: [ios, coredata, avfoundation, pitfalls, bugfix]
---

# iOS 開発 既知の落とし穴

このプロジェクトで実際に発生したバグとその原因・対策を記録する。
同じバグを繰り返さないために、関連する作業の前に必ず参照すること。

---

## 1. CoreData: NSPersistentStoreDescription を URL なしで上書きするとデータが消える

### 症状
アプリを再起動するたびにダウンロードしたファイルとリストが消える。

### 原因
CoreData のマイグレーション設定を追加しようとして、URL なしの `NSPersistentStoreDescription()` を作成し `persistentStoreDescriptions` を上書きした。

```swift
// ❌ NG: URL なしの description で上書き → インメモリストアになる
let description = NSPersistentStoreDescription()  // URL が nil！
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
container.persistentStoreDescriptions = [description]  // デフォルトを破壊
```

URL が nil の description を使うと、CoreData はデフォルトの SQLite ファイルパス
（`Library/Application Support/VideoModel.sqlite`）を失い、インメモリストアで動作する。
アプリを再起動するとメモリが消えてデータが全滅する。

### 対策
`NSPersistentContainer` はデフォルトで lightweight migration が有効なので、
何も追加しなくていい。description を上書きしてはいけない。

```swift
// ✅ OK: 何も上書きしない
init() {
    container = NSPersistentContainer(name: "VideoModel")
    container.loadPersistentStores { _, error in
        if let error { print("Core Data failed to load: \(error)") }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
}
```

もし description を変更する必要がある場合は、必ず既存の description を取得して変更する。
新規作成して置き換えてはいけない。

```swift
// ✅ OK: 既存の description を変更
container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
```

### 検出テスト
`PersistenceControllerTests.swift` に以下のテストを追加済み：
- `testPersistentStoreHasFileURL()` — ストア URL が nil でないことを検証
- `testDataPersistsAcrossControllerReinit()` — 再起動後もデータが残ることを検証

---

## 2. AVAudioSession: デフォルト設定だとサイレントスイッチでミュートされる

### 症状
ダウンロードした動画を再生しても音が出ない（特にサイレントモード時）。

### 原因
`AVAudioSession` のデフォルトカテゴリは `.soloAmbient` で、
iOS のサイレントスイッチ（マナーモード）がオンのときミュートされる。

### 対策
アプリ起動時（`AppDelegate.didFinishLaunchingWithOptions`）に `.playback` カテゴリを設定する。

```swift
// videoPlayerApp.swift AppDelegate 内
do {
    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    try AVAudioSession.sharedInstance().setActive(true)
} catch {
    print("[AudioSession] Failed to configure: \(error)")
}
```

---

## 3. AVAssetImageGenerator: .movpkg のサムネイルは同期 API では取れない

### 症状
HLS ダウンロード（`.movpkg` 形式）の動画一覧でサムネイルが表示されない。

### 原因
`AVAssetImageGenerator.copyCGImage(at:actualTime:)` の同期 API は、
`AVAssetDownloadTask` でダウンロードした `.movpkg`（HLS オフラインバンドル）では動作しない。

### 対策
`AVURLAsset` に変更し、`load(.tracks)` で非同期にトラック情報を先読みしてから
`generateCGImagesAsynchronously` を使う。

```swift
// ✅ OK
Task {
    let asset = AVURLAsset(url: url)
    _ = try? await asset.load(.tracks)  // .movpkg はこれが必要
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.maximumSize = CGSize(width: 240, height: 160)
    let time = CMTime(seconds: 1, preferredTimescale: 600)
    await withCheckedContinuation { continuation in
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, _ in
            if result == .succeeded, let cgImage {
                Task { @MainActor in thumbnail = UIImage(cgImage: cgImage) }
            }
            continuation.resume()
        }
    }
}
```
