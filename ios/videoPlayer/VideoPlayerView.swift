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
    private let videoURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var videoMetadata: VideoMetadata?

    init(store: StoreOf<VideoPlayer>) {
        self.store = store
        let viewStore = ViewStore(store, observe: { $0 })
        if let url = viewStore.fileName.documentDirectoryURL() {
            self.player = AVPlayer(url: url)
            self.videoURL = url
        } else {
            fatalError("Invalid video URL: \(viewStore.fileName)")
        }
        self.viewStore = viewStore
        self.player.volume = Float(viewStore.volume)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // ビデオプレーヤー
                ZStack(alignment: .topLeading) {
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
                        onTimeUpdate: { time in
                            viewStore.send(.updateCurrentTime(time))
                        }
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: isPortraitMode() ? geometry.size.width * 9 / 16 : .infinity
                    )

                    // 閉じるボタン
                    Button(action: {
                        viewStore.send(.savePlaybackPosition)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: closeButtonSize()))
                            .foregroundColor(.white)
                            .frame(width: closeButtonFrameSize(), height: closeButtonFrameSize())
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.top, 16)
                    .padding(.leading, 16)
                }

                // 縦向き時はメタ情報を表示
                if isPortraitMode() {
                    ScrollView {
                        VideoMetadataView(metadata: videoMetadata)
                            .padding()
                    }
                    .background(Color(.systemBackground))
                }
            }
            .background(Color.black)
            .ignoresSafeArea(edges: isPortraitMode() ? [] : .all)
            .onAppear {
                loadVideoMetadata()
            }
            .onDisappear {
                viewStore.send(.savePlaybackPosition)
                if UIDevice.current.orientation.isLandscape {
                    UIDevice.current.setValue(UIDeviceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
            .onChange(of: viewStore.currentTime) { _, newTime in
                // 続きから再生が選択された場合、プレーヤーをシーク
                if newTime > 0 && newTime == viewStore.lastPlaybackPosition {
                    let time = CMTime(seconds: newTime, preferredTimescale: 600)
                    player.seek(to: time)
                }
            }
            .alert(
                "続きから再生",
                isPresented: viewStore.binding(
                    get: \.showResumeAlert,
                    send: .dismissResumeAlert
                )
            ) {
                Button("続きから再生") {
                    viewStore.send(.resumeFromLastPosition)
                }
                Button("最初から再生", role: .cancel) {
                    viewStore.send(.startFromBeginning)
                }
            } message: {
                Text("\(formatTime(viewStore.lastPlaybackPosition)) から再生を再開しますか？")
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func loadVideoMetadata() {
        guard let url = videoURL else { return }

        Task {
            let metadata = await VideoMetadata.load(from: url)
            await MainActor.run {
                self.videoMetadata = metadata
            }
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
// MARK: - Video Metadata

struct VideoMetadata {
    let fileName: String
    let fileSize: String
    let resolution: String
    let duration: String
    let videoCodec: String
    let audioCodec: String
    let frameRate: String
    let bitRate: String
    let creationDate: String

    static func load(from url: URL) async -> VideoMetadata {
        let asset = AVAsset(url: url)

        // ファイル名
        let fileName = url.lastPathComponent

        // ファイルサイズ
        var fileSize = "不明"
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }

        // 再生時間
        var duration = "不明"
        do {
            let durationTime = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(durationTime)
            if !seconds.isNaN {
                let hours = Int(seconds / 3600)
                let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
                let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
                if hours > 0 {
                    duration = String(format: "%d:%02d:%02d", hours, minutes, secs)
                } else {
                    duration = String(format: "%d:%02d", minutes, secs)
                }
            }
        } catch {}

        // 解像度・フレームレート・ビデオコーデック
        var resolution = "不明"
        var frameRate = "不明"
        var videoCodec = "不明"

        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                // 解像度
                let size = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let videoSize = size.applying(transform)
                let width = abs(Int(videoSize.width))
                let height = abs(Int(videoSize.height))
                resolution = "\(width) × \(height)"

                // フレームレート
                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                frameRate = String(format: "%.2f fps", nominalFrameRate)

                // ビデオコーデック
                let formatDescriptions = try await videoTrack.load(.formatDescriptions)
                if let formatDesc = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDesc)
                    videoCodec = fourCharCodeToString(mediaSubType)
                }
            }
        } catch {}

        // オーディオコーデック・ビットレート
        var audioCodec = "不明"
        var bitRate = "不明"

        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = audioTracks.first {
                let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                if let formatDesc = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDesc)
                    audioCodec = fourCharCodeToString(mediaSubType)
                }

                // ビットレート
                let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
                if estimatedDataRate > 0 {
                    bitRate = String(format: "%.0f kbps", estimatedDataRate / 1000)
                }
            }
        } catch {}

        // 作成日時
        var creationDate = "不明"
        do {
            let date = try await asset.load(.creationDate)
            if let dateValue = date?.dateValue {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                creationDate = formatter.string(from: dateValue)
            }
        } catch {}

        return VideoMetadata(
            fileName: fileName,
            fileSize: fileSize,
            resolution: resolution,
            duration: duration,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            frameRate: frameRate,
            bitRate: bitRate,
            creationDate: creationDate
        )
    }

    private static func fourCharCodeToString(_ code: FourCharCode) -> String {
        let chars = [
            Character(UnicodeScalar((code >> 24) & 0xFF)!),
            Character(UnicodeScalar((code >> 16) & 0xFF)!),
            Character(UnicodeScalar((code >> 8) & 0xFF)!),
            Character(UnicodeScalar(code & 0xFF)!)
        ]
        return String(chars)
    }
}

// MARK: - Video Metadata View

struct VideoMetadataView: View {
    let metadata: VideoMetadata?

    var body: some View {
        if let metadata = metadata {
            VStack(alignment: .leading, spacing: 12) {
                Text("動画情報")
                    .font(.headline)
                    .padding(.bottom, 4)

                MetadataRow(label: "ファイル名", value: metadata.fileName)
                MetadataRow(label: "ファイルサイズ", value: metadata.fileSize)
                MetadataRow(label: "解像度", value: metadata.resolution)
                MetadataRow(label: "再生時間", value: metadata.duration)
                MetadataRow(label: "フレームレート", value: metadata.frameRate)
                MetadataRow(label: "映像コーデック", value: metadata.videoCodec)
                MetadataRow(label: "音声コーデック", value: metadata.audioCodec)
                MetadataRow(label: "音声ビットレート", value: metadata.bitRate)
                MetadataRow(label: "作成日時", value: metadata.creationDate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ProgressView("読み込み中...")
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
    }
}

// MARK: - Previews

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
