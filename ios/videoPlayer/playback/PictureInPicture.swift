//
//  PictureInPicture.swift
//  videoPlayer
//
//  ピクチャ・イン・ピクチャ（#14）。
//  - IPTV: 標準コントロールの AVPlayerViewController に任せ、開始/終了だけ追跡する
//  - ローカル動画: 標準コントロールを隠しているため、自前の AVPlayerLayer + AVPictureInPictureController で開始する
//

import AVKit
import UIKit

/// AVPlayerLayer をそのまま backing layer に持つビュー（自前 PiP の描画元）
final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // layerClass で AVPlayerLayer を指定しているので必ず成功する
        layer as! AVPlayerLayer // swiftlint:disable:this force_cast
    }
}

/// PiP の開始/終了を追跡し、PiP から戻るときに画面を復元する。
/// ホームへ戻ったときの自動 PiP は didEnterBackground より先に willStart が来るので、
/// willStart の時点で「PiP 中」とみなし、BackgroundPlaybackCoordinator に映像を切り離させない。
final class PictureInPictureTracker: NSObject {
    private(set) var isActive = false
    var onChange: (Bool) -> Void = { _ in }

    fileprivate func update(_ isActive: Bool) {
        self.isActive = isActive
        onChange(isActive)
    }
}

extension PictureInPictureTracker: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        update(true)
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        update(false)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        update(false)
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // プレイヤー画面は PiP 中も表示されたままなので、そのまま戻せる
        completionHandler(true)
    }
}

extension PictureInPictureTracker: AVPlayerViewControllerDelegate {
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        update(true)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        update(false)
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        update(false)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
