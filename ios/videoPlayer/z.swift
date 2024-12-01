//
//  z.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
import ComposableArchitecture
import SwiftUI
struct MultiVideoPlayerView: View {
    let store: StoreOf<MultiVideoPlayer>

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEachStore(
                    store.scope(
                        state: \.players,
                        action: MultiVideoPlayer.Action.player
                    )
                ) { playerStore in
                    VideoPlayerView(store: playerStore)
                }
            }
            .padding()
        }
    }
}
