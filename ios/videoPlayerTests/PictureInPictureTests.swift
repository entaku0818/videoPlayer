//
//  PictureInPictureTests.swift
//  videoPlayerTests
//

import XCTest
import AVKit
@testable import videoPlayer

final class PictureInPictureTests: XCTestCase {

    // MARK: - ローカル動画プレイヤー

    func testLocalPlayerProvidesPictureInPictureButton() throws {
        let player = AVPlayer()
        let controller = VideoPlayerViewController(player: player, nowPlayingTitle: "テスト")
        controller.loadViewIfNeeded()

        // 標準の PiP は無効化し、自前の PiP コントローラで開始する
        XCTAssertFalse(controller.allowsPictureInPicturePlayback)
        XCTAssertEqual(controller.pictureInPictureButton.accessibilityIdentifier, "pictureInPictureButton")

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            XCTAssertTrue(controller.pictureInPictureButton.isHidden)
            return
        }
        let pictureInPicture = try XCTUnwrap(controller.pictureInPictureController)
        XCTAssertFalse(controller.pictureInPictureButton.isHidden)
        XCTAssertTrue(pictureInPicture.canStartPictureInPictureAutomaticallyFromInline)
        XCTAssertTrue(pictureInPicture.playerLayer.player === player)
    }

    // MARK: - バックグラウンド移行との連携

    func testBackgroundDetachesAdditionalPlayerLayerAndReattachesOnForeground() {
        let (controller, player, layer, coordinator) = makeCoordinator()
        defer { coordinator.invalidate() }
        player.play()

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertNil(controller.player)
        XCTAssertNil(layer.player, "自前 PiP 用レイヤーも切り離さないとシステムに一時停止される")

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(controller.player === player)
        XCTAssertTrue(layer.player === player)
    }

    func testBackgroundKeepsLayersAttachedWhilePictureInPictureIsActive() {
        let (controller, player, layer, coordinator) = makeCoordinator()
        defer { coordinator.invalidate() }
        coordinator.isPictureInPictureActive = { true }
        player.play()

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(controller.player === player, "PiP 中は映像を表示し続ける")
        XCTAssertTrue(layer.player === player)
    }

    func testTrackerReportsStateChanges() {
        let tracker = PictureInPictureTracker()
        var changes: [Bool] = []
        tracker.onChange = { changes.append($0) }
        let playerViewController = AVPlayerViewController()

        tracker.playerViewControllerWillStartPictureInPicture(playerViewController)
        XCTAssertTrue(tracker.isActive)
        tracker.playerViewControllerDidStopPictureInPicture(playerViewController)
        XCTAssertFalse(tracker.isActive)
        XCTAssertEqual(changes, [true, false])

        var restored: Bool?
        tracker.playerViewController(
            playerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: { restored = $0 }
        )
        XCTAssertEqual(restored, true)
    }

    private func makeCoordinator() -> (AVPlayerViewController, AVPlayer, AVPlayerLayer, BackgroundPlaybackCoordinator) {
        let controller = AVPlayerViewController()
        let player = AVPlayer()
        controller.player = player
        let layer = AVPlayerLayer(player: player)
        // 保存済みの設定に左右されないよう空の UserDefaults（= バックグラウンド再生 ON）を使う
        let defaults = UserDefaults(suiteName: "PictureInPictureTests.\(UUID().uuidString)") ?? .standard
        let coordinator = BackgroundPlaybackCoordinator(
            controller: controller, player: player, title: "T", defaults: defaults, onPlay: {}, onPause: {}
        )
        coordinator.additionalPlayerLayer = layer
        coordinator.activate()
        return (controller, player, layer, coordinator)
    }
}
