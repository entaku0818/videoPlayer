//
//  VideoPlayerView.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import AVFoundation

struct VideoPlayerView: View {
    let store: StoreOf<VideoPlayer>
    @ObservedObject var viewStore: ViewStoreOf<VideoPlayer>
    private let player: AVPlayer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(store: StoreOf<VideoPlayer>) {
        self.store = store
        let viewStore = ViewStore(store, observe: { $0 })
        if let url = viewStore.fileName.documentDirectoryURL() {
            self.player = AVPlayer(url: url)
        } else {
            fatalError("Invalid video URL: \(viewStore.fileName)")
        }
        self.viewStore = viewStore
        self.player.volume = Float(viewStore.volume)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // ビデオプレーヤー
                CustomVideoPlayerView(
                    player: player,
                    isPlaying: viewStore.isPlaying,
                    onReady: {
                        viewStore.send(.player(.ready))
                        if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
                            viewStore.send(.updateDuration(duration))
                        }
                    },
                    onPlay: { viewStore.send(.player(.play)) },
                    onPause: { viewStore.send(.player(.pause)) },
                    onFinish: { viewStore.send(.player(.finished)) },
                    onTimeUpdate: { _ in }
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: isPortrait(verticalSizeClass) ? 200 : .infinity
                )
                .ignoresSafeArea(isPortrait(verticalSizeClass) ? .all : .all)

                // 閉じるボタン
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(.top, isPortrait(verticalSizeClass) ? 16 : geometry.safeAreaInsets.top + 16)
                .padding(.leading, 16)
            }
            .padding(isPortrait(verticalSizeClass) ? .vertical : [])
            .navigationBarBackButtonHidden(true)
        }
    }

    private func isPortrait(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        return sizeClass == .regular
    }

    private func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoPlayer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 再生中の状態（縦向き）
            VideoPlayerView(
                store: Store(
                    initialState: VideoPlayer.State(
                        id: UUID(),
                        fileName: "test1.mp4",
                        isPlaying: true,
                        duration: 180,
                        volume: 0.8
                    ),
                    reducer: { VideoPlayer() }
                )
            )
            .previewDisplayName("Playing State - Portrait")

            // 再生中の状態（横向き）
            VideoPlayerView(
                store: Store(
                    initialState: VideoPlayer.State(
                        id: UUID(),
                        fileName: "test3.mp4",
                        isPlaying: true,
                        duration: 180,
                        volume: 0.8
                    ),
                    reducer: { VideoPlayer() }
                )
            )
            .previewInterfaceOrientation(.landscapeRight)
            .previewDisplayName("Playing State - Landscape")
        }
    }
}
