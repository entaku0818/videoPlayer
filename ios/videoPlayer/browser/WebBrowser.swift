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
        var detectedStreams: [DetectedStream] = []
        var downloadingVideoURL: String?
        var downloadProgress: Double = 0
        var errorMessage: String?
        var showVideoList: Bool = false
        var showStreamPlayer: Bool = false
        var selectedStreamURL: String?

        struct DetectedVideo: Equatable, Identifiable {
            let id = UUID()
            let src: String
            let poster: String?
            let type: String?
        }

        struct DetectedStream: Equatable, Identifiable {
            let id = UUID()
            let url: String
            let type: StreamType

            enum StreamType: String, Equatable {
                case hls = "HLS"
                case dash = "DASH"
                case mp4 = "MP4"
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case goButtonTapped
        case loadURL(URL)
        case updateURLBar(URL)
        case pageLoaded
        case videosDetected([State.DetectedVideo])
        case streamsDetected([State.DetectedStream])
        case downloadVideo(String)
        case downloadProgress(Double)
        case downloadCompleted(URL, String)
        case downloadFailed(String)
        case saveVideo(URL, String)
        case videoSaved
        case videoSaveFailed(String)
        case toggleVideoList
        case playStream(String)
        case closeStreamPlayer
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
                let input = state.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !input.isEmpty else { return .none }

                let url: URL

                // URLかどうかを判定
                if isValidURL(input) {
                    var urlString = input
                    if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                        urlString = "https://" + urlString
                    }
                    guard let validURL = URL(string: urlString) else {
                        state.errorMessage = "無効なURLです"
                        return .none
                    }
                    url = validURL
                } else {
                    // 検索クエリとしてGoogle検索
                    guard let encodedQuery = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                          let searchURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)") else {
                        state.errorMessage = "検索できませんでした"
                        return .none
                    }
                    url = searchURL
                }

                state.currentURL = url
                state.isLoading = true
                state.detectedVideos = []
                state.detectedStreams = []
                return .none

            case let .loadURL(url):
                state.currentURL = url
                state.urlString = url.absoluteString
                state.isLoading = true
                state.detectedVideos = []
                state.detectedStreams = []
                return .none

            case let .updateURLBar(url):
                // URLバーのみ更新（ストリーム検出はリセットしない）
                state.urlString = url.absoluteString
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

            case let .streamsDetected(streams):
                // 重複を除去して追加
                let existingURLs = Set(state.detectedStreams.map { $0.url })
                let newStreams = streams.filter { !existingURLs.contains($0.url) }
                state.detectedStreams.append(contentsOf: newStreams)
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

            case let .playStream(urlString):
                state.selectedStreamURL = urlString
                state.showStreamPlayer = true
                return .none

            case .closeStreamPlayer:
                state.showStreamPlayer = false
                state.selectedStreamURL = nil
                return .none

            case .clearError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

// MARK: - Helper Functions

/// 入力がURLかどうかを判定する
private func isValidURL(_ string: String) -> Bool {
    // URLっぽいパターンをチェック
    let urlPatterns = [
        "^https?://",           // http:// or https://
        "^[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}", // domain.tld パターン（例: google.com, example.co.jp）
        "^localhost",           // localhost
        "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}" // IPアドレス
    ]

    for pattern in urlPatterns {
        if string.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
    }

    return false
}
