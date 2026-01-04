//
//  StreamPlayerView.swift
//  videoPlayer
//
//  Created by Claude on 2024/12/30.
//

import SwiftUI
import AVKit

struct StreamPlayerView: View {
    let streamURL: String
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                AVPlayerViewRepresentable(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // 閉じるボタン（左上）
            VStack {
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard let url = URL(string: streamURL) else {
            errorMessage = "無効なURLです"
            return
        }

        // AVPlayerの設定
        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // 自動再生
        avPlayer.play()

        // エラー監視
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                errorMessage = "再生エラー: \(error.localizedDescription)"
            }
        }

        player = avPlayer
    }
}

// MARK: - AVPlayer UIViewRepresentable

struct AVPlayerViewRepresentable: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?

    var player: AVPlayer? {
        didSet {
            setupPlayerLayer()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    private func setupPlayerLayer() {
        playerLayer?.removeFromSuperlayer()

        guard let player = player else { return }

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.playerLayer = layer
    }
}

// MARK: - Fullscreen Stream Player (for sheet presentation)

struct FullscreenStreamPlayerView: View {
    let streamURL: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        StreamPlayerView(streamURL: streamURL) {
            dismiss()
        }
    }
}

#Preview {
    StreamPlayerView(
        streamURL: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        onDismiss: {}
    )
}
