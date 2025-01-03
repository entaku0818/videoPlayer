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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                    maxHeight: videoPlayerHeight(for: geometry)
                )
                .ignoresSafeArea(shouldIgnoreSafeArea())

                // 閉じるボタン
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: closeButtonSize()))
                        .foregroundColor(.white)
                        .frame(width: closeButtonFrameSize(), height: closeButtonFrameSize())
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(.top, closeButtonTopPadding(geometry))
                .padding(.leading, closeButtonLeadingPadding())
            }
            .onDisappear {
                if UIDevice.current.orientation.isLandscape {
                    UIDevice.current.setValue(UIDeviceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // デバイスとサイズクラスに基づいて表示モードを判定
    private func isPortraitMode() -> Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return verticalSizeClass == .regular && horizontalSizeClass == .regular
        }
        return verticalSizeClass == .regular
    }

    // ビデオプレーヤーの高さを計算
    private func videoPlayerHeight(for geometry: GeometryProxy) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {

            return .infinity
        } else {
            // iPhoneの場合
            if isPortraitMode() {
                return 200
            }
            return .infinity
        }
    }

    // SafeAreaの無視判定
    private func shouldIgnoreSafeArea() -> SafeAreaRegions {
        if isPortraitMode() {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return []  // iPadではSafeAreaを尊重
            }
            return .all
        }
        return .all
    }

    // 閉じるボタンのサイズ設定
    private func closeButtonSize() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20
    }

    private func closeButtonFrameSize() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 40 : 30
    }

    // 閉じるボタンの上部パディング
    private func closeButtonTopPadding(_ geometry: GeometryProxy) -> CGFloat {
        if isPortraitMode() {
            return UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
        }
        return geometry.safeAreaInsets.top + 16
    }

    // 閉じるボタンの左側パディング
    private func closeButtonLeadingPadding() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
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

            // iPad用プレビュー（縦向き）
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
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
            .previewDisplayName("iPad - Portrait")

            // iPad用プレビュー（横向き）
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
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
            .previewInterfaceOrientation(.landscapeRight)
            .previewDisplayName("iPad - Landscape")
        }
    }
}
