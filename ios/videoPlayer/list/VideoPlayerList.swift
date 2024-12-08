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

        struct VideoModel: Equatable, Identifiable {
            let id: UUID
            let fileName: String
            let title: String
            let duration: Double
            let createdAt: Date
        }
    }

    enum Action {
        case onAppear
        case videosLoaded(TaskResult<[SavedVideoEntity]>)
        case toggleVideoPicker
        case cancelVideoPicker
        case videoSelected(URL, String, Double)
        case videoSaved(TaskResult<Void>)
        case deleteVideo(State.VideoModel)
        case videoDeleted(TaskResult<Void>)
    }

    @Dependency(\.coreDataClient) var coreDataClient

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
                            createdAt: $0.createdAt
                        )
                    }
                )
                return .none

            case let .videosLoaded(.failure(error)):
                state.isLoading = false
                print("Failed to load videos: \(error)")
                return .none

            case .toggleVideoPicker:
                state.isShowingVideoPicker.toggle()
                return .none
            case .cancelVideoPicker:
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
            }
        }
    }
}
