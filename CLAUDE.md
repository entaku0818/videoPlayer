# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS video player app (Bundle ID: `com.entaku.smartVideoPlayer`) built with SwiftUI and The Composable Architecture (TCA). All source code is under `ios/`.

## Build & Run

Open `ios/videoPlayer.xcodeproj` in Xcode and run on a simulator or device. The app requires sample videos (`video1.mp4`, `video2.mp4`) bundled in the project.

Run tests via Xcode Test Navigator, or from the command line:
```sh
xcodebuild test -project ios/videoPlayer.xcodeproj -scheme videoPlayer -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Fastlane (from `ios/` directory)

```sh
fastlane ios beta              # Build and upload to TestFlight
fastlane ios release           # Build and submit to App Store
fastlane ios upload_metadata   # Upload metadata only (no binary)
fastlane ios download_metadata # Download metadata from App Store Connect
```

Requires environment variables: `APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH`.

## Architecture

**State management**: The Composable Architecture (TCA). Every feature has a `Reducer` (logic) paired with a SwiftUI `View`.

**Dependency injection**: TCA `@Dependency` system. All dependencies conform to `DependencyKey` and expose `liveValue`, `previewValue`, and `testValue`.

### Core Reducers

| Reducer | File | Responsibility |
|---|---|---|
| `VideoPlayerList` | `list/VideoPlayerList.swift` | Root list: load/add/delete videos, URL downloads |
| `VideoPlayer` | `VideoPlayer.swift` | Single video: playback state, resume position |
| `WebBrowser` | `browser/WebBrowser.swift` | In-app browser for discovering and downloading videos |
| `MultiVideoPlayer` | `MultiVideoPlayer.swift` | Manages a collection of `VideoPlayer` reducers (uses TCA `forEach`) |

### TCA Dependencies

- **`CoreDataClient`** (`video/CoreDataClient.swift`): CRUD for the `SavedVideo` CoreData entity — fetches, saves, deletes videos, and reads/writes playback position.
- **`VideoDownloader`** (`download/VideoDownloader.swift`): Downloads video files. Handles direct HTTP downloads and HLS streams (`.m3u8`) via `AVAssetDownloadURLSession`. DASH (`.mpd`) is unsupported.

Both are registered on `DependencyValues` and referenced via `@Dependency(\.coreDataClient)` / `@Dependency(\.videoDownloader)`.

### Data Flow

1. Videos are stored as files in the iOS **Documents directory**, referenced by filename.
2. Metadata (title, duration, last playback position) is stored in **CoreData** (`SavedVideo` entity in `video/VideoModel.xcdatamodeld`).
3. On playback pause/dismiss, `VideoPlayer` saves position via `CoreDataClient.updatePlaybackPosition`. On load, it checks the saved position and offers "resume" or "start from beginning" if >5s progress and <95% complete.

### Player UI Layer

`VideoPlayerViewController` (UIKit, `VideoPlayerViewController.swift`) subclasses `AVPlayerViewController` with custom controls: play/pause, seek bar, playback speed menu (0.5x–2.0x), and rotation button. It is exposed to SwiftUI via `CustomVideoPlayerView` (`UIViewControllerRepresentable`).

`VideoPlayerView` (SwiftUI, `VideoPlayerView.swift`) wraps `CustomVideoPlayerView`, handles orientation (portrait shows video metadata panel, landscape is full-screen), and bridges player events to TCA actions.

### Web Browser Feature

`WebBrowserView` + `WebBrowser` reducer provides an in-app WKWebView browser that detects video elements (`<video>` tags) and streaming URLs (HLS/DASH/MP4) in loaded pages. Detected videos can be downloaded directly or streamed via `StreamPlayerView`.

### Firebase

Firebase is configured at app launch in `AppDelegate`. `GoogleService-Info.plist` must be present in the source directory.

### Xcode Cloud

`ios/ci_scripts/ci_post_clone.sh` runs post-clone to enable Swift Macros (`IDESkipMacroFingerprintValidation`), required because TCA uses Swift Macros.

## ループ運用（Loop Engineering）

このリポジトリは memo リポジトリのプロダクトループ（企画→開発→リリース→効果測定→再企画）の対象。
ここで働くエージェントは以下の規律に従う。

### 起点
- 実装するのは**ユーザーが起票した issue、または `loop-go` ラベル付き issue のみ**。勝手に仕事を選ばない
- 提案がある場合は実装せず、issue コメントか報告として出す

### ハーネス（検証ゲート）
- 実装は build / test / lint が緑になるまで自己修正する（コマンド: `xcodebuild test -project ios/videoPlayer.xcodeproj -scheme videoPlayer -destination 'platform=iOS Simulator,name=iPhone 15'`）
- **緑でない変更を main に入れない**。5回で緑にならなければブランチに残して報告
- 完了報告には実行した検証コマンドと実出力を含める（「たぶん動く」は完了ではない）

### エスカレーション（諦め方の設計）
- 同一 issue に2回挑戦して解けない → `loop-attempted` ラベルを付けて人間へ
- スコープが当初依頼から拡大しそう → 黙って続けず「続けると+N時間 / 切り出すと今すぐ完了」の2択を提示
- 製品挙動の判断（仕様の分かれ道）に当たった → 勝手に決めず、選択肢と推奨を添えて人間へ

### タイムボックス
- 軽微修正30分・機能実装2時間が目安。超える見込みなら途中で現状報告し分割を提案する
- 深い修理（テストスイート全体・インフラ）は issue 化して夜間ループに回すのがデフォルト

### 記録（Persistence）
- 非自明な発見・設計判断は issue かコミットメッセージに残す（次のエージェントの Discovery 入力になる）
- 機能リリース時は対応する提案の「答え合わせキー」をリリースノートに含める（リリース+7日で memo のループが KPI 答え合わせをする）
