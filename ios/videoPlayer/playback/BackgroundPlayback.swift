//
//  BackgroundPlayback.swift
//  videoPlayer
//
//  バックグラウンド音声継続とロック画面/コントロールセンター操作（#15）。
//  映像レイヤーに接続されたままの AVPlayer はバックグラウンド移行時にシステムが一時停止するため、
//  移行時に AVPlayerViewController から player を切り離し、復帰時に再接続する。
//

import AVKit
import MediaPlayer
import OSLog
import UIKit

enum BackgroundPlaybackSettings {
    static let key = "backgroundPlaybackEnabled"

    /// 未設定時は ON
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }
}

enum BackgroundTransitionAction: Equatable {
    /// 映像レイヤーから切り離して音声のみ継続
    case detachVideoLayer
    /// 再生を止める（設定 OFF）
    case pause
    case none
}

enum BackgroundPlaybackPolicy {
    static func onEnterBackground(
        isEnabled: Bool,
        isPlaying: Bool,
        isPictureInPictureActive: Bool
    ) -> BackgroundTransitionAction {
        // PiP 中はシステムが再生を継続するので何もしない
        guard isPlaying, !isPictureInPictureActive else { return .none }
        return isEnabled ? .detachVideoLayer : .pause
    }
}

struct NowPlayingMetadata: Equatable {
    var title: String
    /// nil = ライブ（長さ不定）
    var duration: Double?
    var elapsed: Double
    var rate: Float

    var isLive: Bool { duration == nil }

    init(title: String, duration: Double?, elapsed: Double, rate: Float) {
        self.title = title
        if let duration, duration.isFinite, duration > 0 {
            self.duration = duration
        } else {
            self.duration = nil
        }
        self.elapsed = elapsed.isFinite ? max(0, elapsed) : 0
        self.rate = rate
    }

    var nowPlayingInfo: [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyPlaybackRate: Double(rate),
            MPNowPlayingInfoPropertyIsLiveStream: isLive,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
        ]
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }
        return info
    }
}

final class BackgroundPlaybackCoordinator: NSObject {
    static let skipInterval: Double = 15
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "videoPlayer", category: "BackgroundPlayback")

    /// リモートコマンドと Now Playing は端末で1つなので、最後に有効化したものだけが更新する
    private static weak var current: BackgroundPlaybackCoordinator?

    private weak var controller: AVPlayerViewController?
    private let player: AVPlayer
    private let title: String
    private let onPlay: () -> Void
    private let onPause: () -> Void
    private let defaults: UserDefaults

    private var isDetached = false
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var statusObservation: NSKeyValueObservation?
    private var notificationTokens: [NSObjectProtocol] = []

    init(
        controller: AVPlayerViewController,
        player: AVPlayer,
        title: String,
        defaults: UserDefaults = .standard,
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void
    ) {
        self.controller = controller
        self.player = player
        self.title = title
        self.defaults = defaults
        self.onPlay = onPlay
        self.onPause = onPause
        super.init()
        controller.updatesNowPlayingInfoCenter = false
    }

    deinit {
        invalidate()
    }

    func activate() {
        Self.current = self
        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.didEnterBackground() },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.willEnterForeground() }
        ]
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateNowPlaying() }
        }
        registerRemoteCommands()
        updateNowPlaying()
    }

    func invalidate() {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        notificationTokens.removeAll()
        statusObservation?.invalidate()
        statusObservation = nil
        for (command, target) in commandTargets {
            command.removeTarget(target)
        }
        commandTargets.removeAll()
        if isDetached {
            controller?.player = player
            isDetached = false
        }
        if Self.current === self {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            Self.current = nil
        }
    }

    private var metadata: NowPlayingMetadata {
        NowPlayingMetadata(
            title: title,
            duration: player.currentItem?.duration.seconds,
            elapsed: player.currentTime().seconds,
            rate: player.rate
        )
    }

    private func updateNowPlaying() {
        guard Self.current === self else { return }
        let metadata = metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata.nowPlayingInfo
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.isEnabled = !metadata.isLive
        center.skipBackwardCommand.isEnabled = !metadata.isLive
        center.changePlaybackPositionCommand.isEnabled = !metadata.isLive
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]

        addTarget(center.playCommand) { coordinator, _ in
            coordinator.onPlay()
            return .success
        }
        addTarget(center.pauseCommand) { coordinator, _ in
            coordinator.onPause()
            return .success
        }
        addTarget(center.togglePlayPauseCommand) { coordinator, _ in
            if coordinator.player.timeControlStatus == .paused {
                coordinator.onPlay()
            } else {
                coordinator.onPause()
            }
            return .success
        }
        addTarget(center.skipForwardCommand) { coordinator, _ in
            coordinator.seek(by: Self.skipInterval)
        }
        addTarget(center.skipBackwardCommand) { coordinator, _ in
            coordinator.seek(by: -Self.skipInterval)
        }
        addTarget(center.changePlaybackPositionCommand) { coordinator, event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return coordinator.seek(to: event.positionTime)
        }
    }

    private func addTarget(
        _ command: MPRemoteCommand,
        handler: @escaping (BackgroundPlaybackCoordinator, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            return handler(self, event)
        }
        commandTargets.append((command, target))
    }

    private func seek(by offset: Double) -> MPRemoteCommandHandlerStatus {
        seek(to: player.currentTime().seconds + offset)
    }

    private func seek(to seconds: Double) -> MPRemoteCommandHandlerStatus {
        guard !metadata.isLive else { return .commandFailed }
        let upper = metadata.duration ?? seconds
        let target = min(max(0, seconds), upper)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            DispatchQueue.main.async { self?.updateNowPlaying() }
        }
        return .success
    }

    private func didEnterBackground() {
        let action = BackgroundPlaybackPolicy.onEnterBackground(
            isEnabled: BackgroundPlaybackSettings.isEnabled(defaults),
            isPlaying: player.timeControlStatus != .paused,
            isPictureInPictureActive: false
        )
        logger.info("didEnterBackground status=\(self.player.timeControlStatus.rawValue) action=\(String(describing: action))")
        switch action {
        case .detachVideoLayer:
            controller?.player = nil
            isDetached = true
        case .pause:
            onPause()
        case .none:
            break
        }
        updateNowPlaying()
    }

    private func willEnterForeground() {
        logger.info("willEnterForeground detached=\(self.isDetached) status=\(self.player.timeControlStatus.rawValue)")
        if isDetached {
            controller?.player = player
            isDetached = false
        }
        updateNowPlaying()
    }
}
