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
        // Bundle内の動画ファイルのURLを取得
        let videoNames = ["video1", "video2"] // プロジェクトに追加した動画ファイル名
        let sampleURLs = videoNames.compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "mp4")
        }

        // バンドルに動画がない場合のフォールバック処理
        if sampleURLs.isEmpty {
            fatalError("動画ファイルがプロジェクトに追加されていません。")
        }

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
        VideoPlayerListView(
            store: Store(
                initialState: VideoPlayerList.State(),
                reducer: { VideoPlayerList()._printChanges() }
            )
        )
    }
}

#Preview {
    ContentView()
}
