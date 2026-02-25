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
