//
//  ContentView.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<MultiVideoPlayer>

    init() {
        // サンプルビデオURL（実際のURLに置き換えてください）
        let sampleURLs = [
            URL(string: "https://example.com/video1.mp4")!,
            URL(string: "https://example.com/video2.mp4")!
        ]

        // ストアの初期化
        self.store = Store(
            initialState: MultiVideoPlayer.State(
                players: IdentifiedArrayOf(
                    uniqueElements: sampleURLs.map { url in
                        VideoPlayer.State(
                            id: UUID(),
                            url: url
                        )
                    }
                )
            ),
            reducer: {
                MultiVideoPlayer()._printChanges()
            }
        )
    }

    var body: some View {
        NavigationStack {
            MultiVideoPlayerView(store: store)
                .navigationTitle("Video Player")
        }
    }
}

#Preview {
    ContentView()
}
