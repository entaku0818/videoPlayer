//
//  WebBrowser.swift
//  videoPlayer
//
//  Created by Claude on 2024/12/30.
//

import Foundation
import ComposableArchitecture

@Reducer
struct WebBrowser {
    @ObservableState
    struct State: Equatable {
        var urlString: String = ""
        var currentURL: URL?
        var isLoading: Bool = false
        var detectedVideos: [DetectedVideo] = []
        var downloadingVideoURL: String?
        var downloadProgress: Double = 0
        var errorMessage: String?
        var showVideoList: Bool = false

        struct DetectedVideo: Equatable, Identifiable {
            let id = UUID()
            let src: String
            let poster: String?
            let type: String?
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case goButtonTapped
        case loadURL(URL)
        case pageLoaded
        case videosDetected([State.DetectedVideo])
        case downloadVideo(String)
        case downloadProgress(Double)
        case downloadCompleted(URL, String)
        case downloadFailed(String)
        case saveVideo(URL, String)
        case videoSaved
        case videoSaveFailed(String)
        case toggleVideoList
        case clearError
    }

    @Dependency(\.videoDownloader) var videoDownloader
    @Dependency(\.coreDataClient) var coreDataClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .goButtonTapped:
                var urlString = state.urlString.trimmingCharacters(in: .whitespacesAndNewlines)

                // http/https がなければ追加
                if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                    urlString = "https://" + urlString
                }

                guard let url = URL(string: urlString) else {
                    state.errorMessage = "無効なURLです"
                    return .none
                }

                state.currentURL = url
                state.isLoading = true
                state.detectedVideos = []
                return .none

            case let .loadURL(url):
                state.currentURL = url
                state.urlString = url.absoluteString
                state.isLoading = true
                state.detectedVideos = []
                return .none

            case .pageLoaded:
                state.isLoading = false
                return .none

            case let .videosDetected(videos):
                state.detectedVideos = videos
                if !videos.isEmpty {
                    state.showVideoList = true
                }
                return .none

            case let .downloadVideo(urlString):
                guard let url = URL(string: urlString) else {
                    state.errorMessage = "動画URLが無効です"
                    return .none
                }

                state.downloadingVideoURL = urlString
                state.downloadProgress = 0

                return .run { send in
                    do {
                        let localURL = try await videoDownloader.download(url) { progress in
                            Task { @MainActor in
                                await send(.downloadProgress(progress))
                            }
                        }
                        await send(.downloadCompleted(localURL, urlString))
                    } catch {
                        await send(.downloadFailed(error.localizedDescription))
                    }
                }

            case let .downloadProgress(progress):
                state.downloadProgress = progress
                return .none

            case let .downloadCompleted(localURL, originalURL):
                state.downloadingVideoURL = nil
                state.downloadProgress = 0
                return .send(.saveVideo(localURL, originalURL))

            case let .downloadFailed(error):
                state.downloadingVideoURL = nil
                state.downloadProgress = 0
                state.errorMessage = error
                return .none

            case let .saveVideo(localURL, originalURL):
                let fileName = localURL.lastPathComponent
                let title = URL(string: originalURL)?.lastPathComponent ?? "ダウンロード動画"

                return .run { send in
                    do {
                        try await coreDataClient.saveVideo(localURL, title, 0)
                        await send(.videoSaved)
                    } catch {
                        await send(.videoSaveFailed(error.localizedDescription))
                    }
                }

            case .videoSaved:
                return .none

            case let .videoSaveFailed(error):
                state.errorMessage = "保存失敗: \(error)"
                return .none

            case .toggleVideoList:
                state.showVideoList.toggle()
                return .none

            case .clearError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
