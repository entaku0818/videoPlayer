//
//  VideoPlayerViewController.swift
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
    private let controlsContainer = UIView()
    private let playPauseButton = UIButton(type: .system)
    private let buttonBackground = UIView()
    private let seekBar = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let bottomControlsContainer = UIView()
    private let speedButton = UIButton(type: .system)
    private let speedMenu: UIMenu
    private let availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private var currentSpeedIndex = 2 // デフォルトは1.0倍

    private var isControlsVisible = true {
        didSet {
            updateControlsVisibility()
        }
    }

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
                updatePlayPauseButton()
                startControlsAutoHideTimer()
                player?.rate = Float(availableSpeeds[currentSpeedIndex])
            } else {
                player?.pause()
                onPause()
                updatePlayPauseButton()
                stopControlsAutoHideTimer()
            }
        }
    }

    private var controlsAutoHideTimer: Timer?
    private let controlsAutoHideInterval: TimeInterval = 3.0

    init(player: AVPlayer) {
        speedMenu = UIMenu(title: "再生速度", children: [])

        super.init(nibName: nil, bundle: nil)
        self.player = player

        setupSpeedMenu()
        setupPlayer()
        setupCustomControls()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)

        DispatchQueue.main.async { [weak self] in
            // 親ビューコントローラーも含めて更新
            self?.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            self?.tabBarController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            self?.setNeedsUpdateOfSupportedInterfaceOrientations()

            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                print("Orientation error: \(error)")

            }

            // 回転を即時反映
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSpeedMenu() {
        var menuItems: [UIAction] = []

        for (index, speed) in availableSpeeds.enumerated() {
            let action = UIAction(
                title: "\(speed)x",
                state: index == currentSpeedIndex ? .on : .off
            ) { [weak self] _ in
                self?.changePlaybackSpeed(toIndex: index)
            }
            menuItems.append(action)
        }

        speedButton.menu = UIMenu(title: "再生速度", children: menuItems)
        speedButton.showsMenuAsPrimaryAction = true
    }

    private func setupPlayer() {
        guard let player = player else { return }
        showsPlaybackControls = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: time,
            queue: .main
        ) { [weak self] time in
            self?.updateTimeDisplay(currentTime: time.seconds)
            self?.onTimeUpdate(time.seconds)
        }

        if let duration = player.currentItem?.duration.seconds,
           !duration.isNaN {
            logger.debug("Player ready with duration: \(duration)")
            updateTimeDisplay(duration: duration)
            onReady()
        }

        player.currentItem?.addObserver(
            self,
            forKeyPath: #keyPath(AVPlayerItem.status),
            options: [.new, .old],
            context: nil
        )
    }

    private func setupCustomControls() {
        // コントロールコンテナの設定
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)

        // 再生/一時停止ボタンの背景
        buttonBackground.translatesAutoresizingMaskIntoConstraints = false
        buttonBackground.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        buttonBackground.layer.cornerRadius = 35

        // 下部コントロール用の背景
        let bottomGradient = CAGradientLayer()
        bottomGradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        bottomGradient.locations = [0.0, 1.0]
        bottomControlsContainer.layer.insertSublayer(bottomGradient, at: 0)

        // UI部品の設定
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)

        seekBar.translatesAutoresizingMaskIntoConstraints = false
        seekBar.tintColor = .white
        seekBar.addTarget(self, action: #selector(seekBarValueChanged), for: .valueChanged)
        seekBar.addTarget(self, action: #selector(seekBarTouchEnded), for: [.touchUpInside, .touchUpOutside])

        [currentTimeLabel, durationLabel].forEach { label in
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .white
            label.font = .systemFont(ofSize: 12)
        }

        // スピードボタンの設定
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        speedButton.tintColor = .white
        speedButton.setTitle("1.0x", for: .normal)
        speedButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        speedButton.layer.cornerRadius = 15
        speedButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        // ビューの追加
        controlsContainer.addSubview(buttonBackground)
        controlsContainer.addSubview(playPauseButton)
        view.addSubview(bottomControlsContainer)
        bottomControlsContainer.addSubview(seekBar)
        bottomControlsContainer.addSubview(currentTimeLabel)
        bottomControlsContainer.addSubview(durationLabel)
        bottomControlsContainer.addSubview(speedButton)

        // レイアウト制約
        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.topAnchor.constraint(equalTo: view.topAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonBackground.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            buttonBackground.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            buttonBackground.widthAnchor.constraint(equalToConstant: 70),
            buttonBackground.heightAnchor.constraint(equalToConstant: 70),

            playPauseButton.centerXAnchor.constraint(equalTo: buttonBackground.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: buttonBackground.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60),
            playPauseButton.heightAnchor.constraint(equalToConstant: 60),

            bottomControlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomControlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomControlsContainer.heightAnchor.constraint(equalToConstant: 80),

            speedButton.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            speedButton.topAnchor.constraint(equalTo: bottomControlsContainer.topAnchor, constant: 8),

            currentTimeLabel.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor, constant: 16),
            currentTimeLabel.bottomAnchor.constraint(equalTo: bottomControlsContainer.bottomAnchor, constant: -8),

            durationLabel.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            durationLabel.bottomAnchor.constraint(equalTo: bottomControlsContainer.bottomAnchor, constant: -8),

            seekBar.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor, constant: 16),
            seekBar.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            seekBar.bottomAnchor.constraint(equalTo: currentTimeLabel.topAnchor, constant: -8),
            seekBar.topAnchor.constraint(equalTo: speedButton.bottomAnchor, constant: 8)
        ])

        // タップジェスチャーの追加
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGesture)

        updatePlayPauseButton()

        // グラデーションのフレーム設定
        view.layoutIfNeeded()
        bottomGradient.frame = bottomControlsContainer.bounds
    }

    private func updateControlsVisibility() {
        UIView.animate(withDuration: 0.3) {
            self.playPauseButton.alpha = self.isControlsVisible ? 1 : 0
            self.buttonBackground.alpha = self.isControlsVisible ? 1 : 0
            self.bottomControlsContainer.alpha = self.isControlsVisible ? 1 : 0
            self.speedButton.alpha = self.isControlsVisible ? 1 : 0
        }
    }

    private func startControlsAutoHideTimer() {
        stopControlsAutoHideTimer()
        if isPlaying && isControlsVisible {
            controlsAutoHideTimer = Timer.scheduledTimer(
                withTimeInterval: controlsAutoHideInterval,
                repeats: false
            ) { [weak self] _ in
                self?.isControlsVisible = false
            }
        }
    }

    private func stopControlsAutoHideTimer() {
        controlsAutoHideTimer?.invalidate()
        controlsAutoHideTimer = nil
    }

    private func changePlaybackSpeed(toIndex index: Int) {
        guard index >= 0 && index < availableSpeeds.count else { return }

        currentSpeedIndex = index
        let speed = availableSpeeds[index]

        player?.rate = Float(speed)
        speedButton.setTitle("\(speed)x", for: .normal)
        setupSpeedMenu()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)

        if bottomControlsContainer.frame.contains(location) {
            return
        }

        let centerRegion = view.bounds.insetBy(dx: view.bounds.width * 0.3, dy: view.bounds.height * 0.3)
        if centerRegion.contains(location) {
            togglePlayPause()
        }

        isControlsVisible.toggle()
        if isControlsVisible {
            startControlsAutoHideTimer()
        }
    }

    @objc private func seekBarValueChanged() {
        stopControlsAutoHideTimer()
        if let duration = player?.currentItem?.duration.seconds {
            let targetTime = Double(seekBar.value) * duration
            updateTimeDisplay(currentTime: targetTime)
        }
    }

    @objc private func seekBarTouchEnded() {
        if let duration = player?.currentItem?.duration.seconds {
            let targetTime = Double(seekBar.value) * duration
            let time = CMTime(seconds: targetTime, preferredTimescale: 600)
            player?.seek(to: time)
            startControlsAutoHideTimer()
        }
    }

    private func updateTimeDisplay(currentTime: Double? = nil, duration: Double? = nil) {
        if let currentTime = currentTime {
            currentTimeLabel.text = formatTime(currentTime)
            if let duration = player?.currentItem?.duration.seconds {
                seekBar.value = Float(currentTime / duration)
            }
        }

        if let duration = duration {
            durationLabel.text = formatTime(duration)
        }
    }

    private func formatTime(_ timeInSeconds: Double) -> String {
        let hours = Int(timeInSeconds / 3600)
        let minutes = Int(timeInSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(timeInSeconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func updatePlayPauseButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let image = UIImage(
            systemName: isPlaying ? "pause.fill" : "play.fill",
            withConfiguration: symbolConfiguration
        )
        playPauseButton.setImage(image, for: .normal)
    }

    @objc private func togglePlayPause() {
        isPlaying.toggle()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            if let statusNumber = change?[.newKey] as? NSNumber,
               let status = AVPlayerItem.Status(rawValue: statusNumber.intValue) {
                switch status {
                case .readyToPlay:
                    logger.debug("Player ready to play")
                    if let duration = player?.currentItem?.duration.seconds {
                        updateTimeDisplay(duration: duration)
                    }
                    player?.rate = Float(availableSpeeds[currentSpeedIndex])
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
        stopControlsAutoHideTimer()
        logger.debug("VideoPlayerViewController deinitialized")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradientLayer = bottomControlsContainer.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = bottomControlsContainer.bounds
        }
    }
}

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

struct CustomVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerPreviewContainer()
            .previewInterfaceOrientation(.landscapeRight)

    }

    // プレビュー用のコンテナビュー
    private struct VideoPlayerPreviewContainer: View {
        @State private var isPlaying = false
        let player = AVPlayer(url: Bundle.main.url(forResource: "sample", withExtension: "mp4") ?? URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4")!)

        var body: some View {
            CustomVideoPlayerView(
                player: player,
                isPlaying: isPlaying,
                onReady: {
                    print("Player ready")
                },
                onPlay: {
                    print("Playing")
                    isPlaying = true
                },
                onPause: {
                    print("Paused")
                    isPlaying = false
                },
                onFinish: {
                    print("Finished")
                    isPlaying = false
                },
                onTimeUpdate: { time in
                    print("Time update: \(time)")
                }
            )
            .onAppear {
                // プレビュー表示時に自動再生する場合はコメントを解除
                // isPlaying = true
            }
            .onDisappear {
                // プレビュー終了時に再生を停止
                player.pause()
            }
        }
    }
}
