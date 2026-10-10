//
//  BackgroundPlaybackTests.swift
//  videoPlayerTests
//

import XCTest
import AVKit
import MediaPlayer
@testable import videoPlayer

final class BackgroundPlaybackTests: XCTestCase {

    // MARK: - Info.plist

    func testAppDeclaresAudioBackgroundMode() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertEqual(modes, ["audio"])
    }

    // MARK: - 設定

    func testSettingDefaultsToEnabledAndCanBeDisabled() throws {
        let suite = "BackgroundPlaybackTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertTrue(BackgroundPlaybackSettings.isEnabled(defaults))
        defaults.set(false, forKey: BackgroundPlaybackSettings.key)
        XCTAssertFalse(BackgroundPlaybackSettings.isEnabled(defaults))
        // 起動引数（-backgroundPlaybackEnabled NO）は文字列として入る
        defaults.set("NO", forKey: BackgroundPlaybackSettings.key)
        XCTAssertFalse(BackgroundPlaybackSettings.isEnabled(defaults))
    }

    // MARK: - バックグラウンド移行時の判定

    func testPolicyDetachesVideoLayerWhenEnabledAndPlaying() {
        XCTAssertEqual(
            BackgroundPlaybackPolicy.onEnterBackground(isEnabled: true, isPlaying: true, isPictureInPictureActive: false),
            .detachVideoLayer
        )
    }

    func testPolicyPausesWhenDisabled() {
        XCTAssertEqual(
            BackgroundPlaybackPolicy.onEnterBackground(isEnabled: false, isPlaying: true, isPictureInPictureActive: false),
            .pause
        )
    }

    func testPolicyDoesNothingWhenPausedOrInPictureInPicture() {
        XCTAssertEqual(
            BackgroundPlaybackPolicy.onEnterBackground(isEnabled: true, isPlaying: false, isPictureInPictureActive: false),
            .none
        )
        XCTAssertEqual(
            BackgroundPlaybackPolicy.onEnterBackground(isEnabled: true, isPlaying: true, isPictureInPictureActive: true),
            .none
        )
    }

    // MARK: - Now Playing

    func testNowPlayingInfoForLocalVideo() {
        let metadata = NowPlayingMetadata(title: "旅行", duration: 120, elapsed: 30, rate: 1)
        let info = metadata.nowPlayingInfo

        XCTAssertFalse(metadata.isLive)
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "旅行")
        XCTAssertEqual(info[MPMediaItemPropertyPlaybackDuration] as? Double, 120)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 30)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyIsLiveStream] as? Bool, false)
    }

    func testIndefiniteDurationIsTreatedAsLive() {
        // ライブ HLS の duration は indefinite（NaN）になる
        let metadata = NowPlayingMetadata(title: "Ch", duration: CMTime.indefinite.seconds, elapsed: .nan, rate: 0)
        let info = metadata.nowPlayingInfo

        XCTAssertTrue(metadata.isLive)
        XCTAssertEqual(metadata.elapsed, 0)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyIsLiveStream] as? Bool, true)
        XCTAssertNil(info[MPMediaItemPropertyPlaybackDuration])
        XCTAssertNil(info[MPNowPlayingInfoPropertyElapsedPlaybackTime])
    }

    // MARK: - Coordinator

    func testCoordinatorPublishesAndClearsNowPlaying() {
        let controller = AVPlayerViewController()
        let player = AVPlayer()
        let coordinator = BackgroundPlaybackCoordinator(
            controller: controller, player: player, title: "テスト", onPlay: {}, onPause: {}
        )

        XCTAssertFalse(controller.updatesNowPlayingInfoCenter)
        coordinator.activate()
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "テスト")

        coordinator.invalidate()
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func testRemotePauseCommandIsForwardedToHost() {
        let controller = AVPlayerViewController()
        let player = AVPlayer()
        var paused = 0
        let coordinator = BackgroundPlaybackCoordinator(
            controller: controller, player: player, title: "T", onPlay: {}, onPause: { paused += 1 }
        )
        coordinator.activate()
        defer { coordinator.invalidate() }

        XCTAssertTrue(MPRemoteCommandCenter.shared().pauseCommand.isEnabled)
        XCTAssertFalse(MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled, "長さ不明（ライブ扱い）はスキップ不可")
        XCTAssertEqual(paused, 0)
    }
}
