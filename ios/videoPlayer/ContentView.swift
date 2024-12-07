//
//  ContentView.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import SwiftUI
import ComposableArchitecture
import os 


struct ContentView: View {
    let store: StoreOf<MultiVideoPlayer>


    init() {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "videoPlayer", category: "FileSystem")

        let videoNames = ["video1", "video2"]
        let sampleURLs = videoNames.compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "mp4")
        }

        if sampleURLs.isEmpty {
            fatalError("動画ファイルがプロジェクトに追加されていません。")
        }

        // Documentsディレクトリのパスを取得して表示
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logger.info("Documents directoryのパス: \(documentsPath.path)")

            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: documentsPath,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                logger.info("=== ファイル一覧 ===")
                for (index, fileURL) in fileURLs.enumerated() {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    logger.info("[\(index + 1)] ファイル名: \(fileURL.lastPathComponent)")
                    logger.info("    パス: \(fileURL.path)")
                }

                if fileURLs.isEmpty {
                    logger.notice("ディレクトリは空です")
                }
            } catch {
                logger.error("ファイル一覧取得エラー: \(error.localizedDescription)")
            }
        }

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
