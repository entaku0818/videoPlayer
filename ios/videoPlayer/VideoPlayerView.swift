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

