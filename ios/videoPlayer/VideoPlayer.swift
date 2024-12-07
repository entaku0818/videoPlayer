//
//  VideoPlayer.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
import ComposableArchitecture
struct VideoPlayer: Reducer {
    struct State: Equatable, Identifiable {
        let id: UUID
        var fileName: String
        var isPlaying: Bool = false
        var duration: Double = 0
        var volume: Double = 1.0
    }

    enum Action {
        case togglePlayback
        case updateDuration(Double)
        case setVolume(Double)
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

            case .player(.ready):
                return .none

            case .player(.play):
                state.isPlaying = true
                return .none

            case .player(.pause):
                state.isPlaying = false
                return .none

            case .player(.finished):
                state.isPlaying = false
                return .none
            }
        }
    }
}
