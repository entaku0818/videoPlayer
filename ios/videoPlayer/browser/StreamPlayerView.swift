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
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    AVPlayerViewRepresentable(player: player)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
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

                // Controls overlay
                if showControls {
                    VStack {
                        // Top bar
                        HStack {
                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }

                            Spacer()

                            // PiP button (iOS 14+)
                            if AVPictureInPictureController.isPictureInPictureSupported() {
                                Button {
                                    // PiP is handled automatically by VideoPlayer
                                } label: {
                                    Image(systemName: "pip.enter")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding()

                        Spacer()

                        // Stream URL info
                        Text(streamURL)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
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
        isPlaying = true

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

struct AVPlayerViewRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
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
