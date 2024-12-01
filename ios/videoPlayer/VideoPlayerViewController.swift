//
//  v.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
import SwiftUI
import AVKit
import OSLog

class VideoPlayerViewController: AVPlayerViewController {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "VideoPlayer", category: "VideoPlayerViewController")

    // コールバック
    var onReady: () -> Void = {}
    var onPlay: () -> Void = {}
    var onPause: () -> Void = {}
    var onFinish: () -> Void = {}
    var onTimeUpdate: (Double) -> Void = { _ in }

    private var timeObserver: Any?
    private var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                player?.play()
                onPlay()
            } else {
                player?.pause()
                onPause()
            }
        }
    }

    init(player: AVPlayer) {
        super.init(nibName: nil, bundle: nil)
        self.player = player
        setupPlayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPlayer() {
        guard let player = player else { return }

        showsPlaybackControls = true

        // 再生状態の監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        // 再生時間の定期的な監視
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: time,
            queue: .main
        ) { [weak self] time in
            self?.logger.debug("time.seconds: \(time.seconds)")

            self?.onTimeUpdate(time.seconds)
        }

        // 準備完了時の処理
        if let duration = player.currentItem?.duration.seconds,
           !duration.isNaN {
            logger.debug("Player ready with duration: \(duration)")
            onReady()
        }

        // アイテムの状態監視
        player.currentItem?.addObserver(
            self,
            forKeyPath: #keyPath(AVPlayerItem.status),
            options: [.new, .old],
            context: nil
        )
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            if let statusNumber = change?[.newKey] as? NSNumber,
               let status = AVPlayerItem.Status(rawValue: statusNumber.intValue) {
                switch status {
                case .readyToPlay:
                    logger.debug("Player ready to play")
                    onReady()
                case .failed:
                    if let error = player?.currentItem?.error {
                        logger.error("Player failed: \(error.localizedDescription)")
                    }
                case .unknown:
                    logger.warning("Player status unknown")
                @unknown default:
                    logger.warning("Player status unexpected: \(status.rawValue)")
                }
            }
        }
    }

    @objc private func playerDidFinishPlaying() {
        logger.debug("Player finished playing")
        isPlaying = false
        onFinish()
    }

    func updatePlayback(isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        NotificationCenter.default.removeObserver(self)
        logger.debug("VideoPlayerViewController deinitialized")
    }
}

// VideoPlayerView.swift
import SwiftUI
import AVKit

struct CustomVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let isPlaying: Bool
    let onReady: () -> Void
    let onPlay: () -> Void
    let onPause: () -> Void
    let onFinish: () -> Void
    let onTimeUpdate: (Double) -> Void

    func makeUIViewController(context: Context) -> VideoPlayerViewController {
        let controller = VideoPlayerViewController(player: player)
        controller.onReady = onReady
        controller.onPlay = onPlay
        controller.onPause = onPause
        controller.onFinish = onFinish
        controller.onTimeUpdate = onTimeUpdate
        return controller
    }

    func updateUIViewController(_ uiViewController: VideoPlayerViewController, context: Context) {
        uiViewController.updatePlayback(isPlaying: isPlaying)
    }
}
