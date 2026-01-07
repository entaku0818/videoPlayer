//
//  VideoPlayer.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
import ComposableArchitecture
import Dependencies

struct VideoPlayer: Reducer {
    @Dependency(\.coreDataClient) var coreDataClient

    struct State: Equatable, Identifiable {
        let id: UUID
        var fileName: String
        var isPlaying: Bool = false
        var duration: Double = 0
        var volume: Double = 1.0
        var currentTime: Double = 0
        var lastPlaybackPosition: Double = 0
        var showResumeAlert: Bool = false
    }

    enum Action {
        case togglePlayback
        case updateDuration(Double)
        case setVolume(Double)
        case updateCurrentTime(Double)
        case savePlaybackPosition
        case loadPlaybackPosition
        case playbackPositionLoaded(Double)
        case resumeFromLastPosition
        case startFromBeginning
        case dismissResumeAlert
        case player(PlayerAction)

        enum PlayerAction {
            case ready
            case play
            case pause
            case finished
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .togglePlayback:
                state.isPlaying.toggle()
                return .none

            case let .updateDuration(duration):
                state.duration = duration
                return .none

            case let .setVolume(volume):
                state.volume = volume
                return .none

            case let .updateCurrentTime(time):
                state.currentTime = time
                return .none

            case .savePlaybackPosition:
                let id = state.id
                let position = state.currentTime
                return .run { _ in
                    try await coreDataClient.updatePlaybackPosition(id, position)
                }

            case .loadPlaybackPosition:
                let id = state.id
                return .run { send in
                    let position = try await coreDataClient.getPlaybackPosition(id)
                    await send(.playbackPositionLoaded(position))
                }

            case let .playbackPositionLoaded(position):
                state.lastPlaybackPosition = position
                // 5秒以上再生していて、95%未満なら続きから再生を提案
                if position > 5 && state.duration > 0 && (position / state.duration) < 0.95 {
                    state.showResumeAlert = true
                }
                return .none

            case .resumeFromLastPosition:
                state.showResumeAlert = false
                state.currentTime = state.lastPlaybackPosition
                return .none

            case .startFromBeginning:
                state.showResumeAlert = false
                state.currentTime = 0
                return .none

            case .dismissResumeAlert:
                state.showResumeAlert = false
                return .none

            case .player(.ready):
                return .send(.loadPlaybackPosition)

            case .player(.play):
                state.isPlaying = true
                return .none

            case .player(.pause):
                state.isPlaying = false
                return .send(.savePlaybackPosition)

            case .player(.finished):
                state.isPlaying = false
                // 最後まで見たら位置をリセット
                let id = state.id
                return .run { _ in
                    try await coreDataClient.updatePlaybackPosition(id, 0)
                }
            }
        }
    }
}
