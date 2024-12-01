//
//  a.swift
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
        self.player = AVPlayer(url: viewStore.url)        
        self.viewStore = viewStore

        // プレイヤーの初期音量を設定
        self.player.volume = Float(viewStore.volume)
    }

    var body: some View {
        VStack {
            CustomVideoPlayer(
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
                onTimeUpdate: { viewStore.send(.updateTime($0)) }
            )
            .frame(height: 200)

            VStack(spacing: 12) {
                // 再生時間スライダー
                HStack {
                    Text(timeString(viewStore.currentTime))
                        .font(.caption)
                        .monospacedDigit()

                    Slider(
                        value: viewStore.binding(
                            get: \.currentTime,
                            send: VideoPlayer.Action.seek
                        ),
                        in: 0...max(viewStore.duration, 0.01)
                    )
                    .onChange(of: viewStore.currentTime) { newValue in
                        let time = CMTime(seconds: newValue, preferredTimescale: 600)
                        player.seek(to: time)
                    }

                    Text(timeString(viewStore.duration))
                        .font(.caption)
                        .monospacedDigit()
                }

                // 音量スライダー
                HStack {
                    Image(systemName: "speaker.wave.1")
                        .foregroundColor(.gray)

                    Slider(
                        value: viewStore.binding(
                            get: \.volume,
                            send: VideoPlayer.Action.setVolume
                        ),
                        in: 0...1
                    )
                    .onChange(of: viewStore.volume) { newValue in
                        player.volume = Float(newValue)
                    }

                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

