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

    init(store: StoreOf<VideoPlayer>) {
        self.store = store
        let viewStore = ViewStore(store, observe: { $0 })
        if let url = viewStore.fileName.documentDirectoryURL() {
            self.player = AVPlayer(url: url)
        } else {
            fatalError("Invalid video URL: \(viewStore.fileName)")
        }       
        self.viewStore = viewStore

        // プレイヤーの初期音量を設定
        self.player.volume = Float(viewStore.volume)
    }

    var body: some View {
        VStack {
            CustomVideoPlayerView(
                player: player,
                isPlaying: viewStore.isPlaying,
                onReady: {
                    viewStore.send(.player(.ready))
                    // 動画の長さを取得して保存
                    if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
                        viewStore.send(.updateDuration(duration))
                    }
                },
                onPlay: { viewStore.send(.player(.play)) },
                onPause: { viewStore.send(.player(.pause)) },
                onFinish: { viewStore.send(.player(.finished)) },
                onTimeUpdate: {_ in 
                    
                }
            )
            .frame(height: 200)

        }
        .padding(.vertical)
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

            // 一時停止状態（縦向き）
            VideoPlayerView(
                store: Store(
                    initialState: VideoPlayer.State(
                        id: UUID(),
                        fileName: "test2.mp4",
                        isPlaying: false,
                        duration: 240,
                        volume: 0.5
                    ),
                    reducer: { VideoPlayer() }
                )
            )
            .previewDisplayName("Paused State - Portrait")

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
