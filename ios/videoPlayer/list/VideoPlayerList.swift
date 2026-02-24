//
//  VideoPlayerList.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/02.
//

import Foundation
import ComposableArchitecture
struct VideoPlayerList: Reducer {
    struct State: Equatable {
        var videos: IdentifiedArrayOf<VideoModel> = []
        var isShowingVideoPicker = false
        var selectedVideo: VideoModel?
        var isLoading = false

        // URL直接ダウンロード用
        var isShowingURLInput = false
        var urlInputText = ""
        var isDownloading = false
        var downloadProgress: Double = 0
        var downloadError: String?

        struct VideoModel: Equatable, Identifiable {
            let id: UUID
            let fileName: String
            let title: String
            let duration: Double
            let createdAt: Date
            let lastPlaybackPosition: Double
            let lastPlayedAt: Date?
            let sourceURL: String?
            let videoType: String?

            var isLocalVideo: Bool { videoType == nil || videoType == "local" }

            var playbackProgress: Double {
                guard duration > 0 else { return 0 }
                return lastPlaybackPosition / duration
            }

            var canResumePlayback: Bool {
                lastPlaybackPosition > 5 && playbackProgress < 0.95
            }
        }
    }

    enum Action {
        case onAppear
        case videosLoaded(TaskResult<[SavedVideoEntity]>)
        case openVideoPicker
        case closeVideoPicker
        case videoSelected(URL, String, Double)
        case videoSaved(TaskResult<Void>)
        case deleteVideo(State.VideoModel)
        case videoDeleted(TaskResult<Void>)

        // URL直接ダウンロード用
        case openURLInput
        case closeURLInput
        case updateURLInput(String)
        case downloadFromURL
        case downloadProgress(Double)
        case downloadCompleted(URL)
        case downloadFailed(String)
        case clearDownloadError
        case saveSNSVideo(URL, String)
    }

    @Dependency(\.coreDataClient) var coreDataClient
    @Dependency(\.videoDownloader) var videoDownloader

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.videosLoaded(
                        TaskResult { try await coreDataClient.fetchVideos() }
                    ))
                }

            case let .videosLoaded(.success(videos)):
                state.isLoading = false
                state.videos = IdentifiedArrayOf(
                    uniqueElements: videos.map {
                        State.VideoModel(
                            id: $0.id,
                            fileName: $0.fileName,
                            title: $0.title,
                            duration: $0.duration,
                            createdAt: $0.createdAt,
                            lastPlaybackPosition: $0.lastPlaybackPosition,
                            lastPlayedAt: $0.lastPlayedAt,
                            sourceURL: $0.sourceURL,
                            videoType: $0.videoType
                        )
                    }
                )
                return .none

            case let .videosLoaded(.failure(error)):
                state.isLoading = false
                print("Failed to load videos: \(error)")
                return .none

            case .openVideoPicker:
                state.isShowingVideoPicker = true
                return .none
            case .closeVideoPicker:
                state.isShowingVideoPicker = false
                return .none
            case let .videoSelected(url, title, duration):
                return .run { send in
                    await send(.videoSaved(
                        TaskResult {
                            try await coreDataClient.saveVideo(
                                url,
                                title,
                                duration
                            )
                        }
                    ))
                    await send(.onAppear)
                }

            case .videoSaved(.success):
                return .none

            case let .videoSaved(.failure(error)):
                print("Failed to save video: \(error)")
                return .none

            case let .deleteVideo(video):
                return .run { send in
                    await send(.videoDeleted(
                        TaskResult {
                            try await coreDataClient.deleteVideo(video.id)
                        }
                    ))
                    await send(.onAppear)
                }

            case .videoDeleted(.success):
                return .none

            case let .videoDeleted(.failure(error)):
                print("Failed to delete video: \(error)")
                return .none

            // URL直接ダウンロード
            case .openURLInput:
                state.isShowingURLInput = true
                state.urlInputText = ""
                return .none

            case .closeURLInput:
                state.isShowingURLInput = false
                return .none

            case let .updateURLInput(text):
                state.urlInputText = text
                return .none

            case .downloadFromURL:
                var urlString = state.urlInputText.trimmingCharacters(in: .whitespacesAndNewlines)

                if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                    urlString = "https://" + urlString
                }

                guard let url = URL(string: urlString) else {
                    state.downloadError = "無効なURLです"
                    return .none
                }

                state.isShowingURLInput = false

                if let snsType = detectSNSType(from: url) {
                    return .run { send in
                        await send(.saveSNSVideo(url, snsType))
                    }
                }

                state.isDownloading = true
                state.downloadProgress = 0

                return .run { send in
                    do {
                        let localURL = try await videoDownloader.download(url) { progress in
                            Task { @MainActor in
                                await send(.downloadProgress(progress))
                            }
                        }
                        await send(.downloadCompleted(localURL))
                    } catch {
                        await send(.downloadFailed(error.localizedDescription))
                    }
                }

            case let .saveSNSVideo(url, videoType):
                let title = generateSNSTitle(from: url, videoType: videoType)
                return .run { send in
                    await send(.videoSaved(
                        TaskResult {
                            try await coreDataClient.saveSNSVideo(url.absoluteString, title, videoType)
                        }
                    ))
                    await send(.onAppear)
                }

            case let .downloadProgress(progress):
                state.downloadProgress = progress
                return .none

            case let .downloadCompleted(localURL):
                state.isDownloading = false
                state.downloadProgress = 0

                let title = localURL.deletingPathExtension().lastPathComponent

                return .run { send in
                    await send(.videoSaved(
                        TaskResult {
                            try await coreDataClient.saveVideo(localURL, title, 0)
                        }
                    ))
                    await send(.onAppear)
                }

            case let .downloadFailed(error):
                state.isDownloading = false
                state.downloadProgress = 0
                state.downloadError = error
                return .none

            case .clearDownloadError:
                state.downloadError = nil
                return .none
            }
        }
    }

    private func detectSNSType(from url: URL) -> String? {
        let host = url.host ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") { return "youtube" }
        if host.contains("twitter.com") || host.contains("x.com") { return "twitter" }
        if host.contains("instagram.com") { return "instagram" }
        return nil
    }

    private func generateSNSTitle(from url: URL, videoType: String) -> String {
        switch videoType {
        case "youtube":
            return "YouTube: \(url.path.prefix(40))"
        case "twitter":
            return "Twitter/X: \(url.path.prefix(40))"
        case "instagram":
            return "Instagram: \(url.path.prefix(40))"
        default:
            return url.absoluteString
        }
    }
}
