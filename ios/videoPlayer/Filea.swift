//
//  MultiVideoPlayer.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
import ComposableArchitecture
struct MultiVideoPlayer: Reducer {
    struct State: Equatable {
        var players: IdentifiedArrayOf<VideoPlayer.State>
    }

    enum Action {
        case player(id: VideoPlayer.State.ID, action: VideoPlayer.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
        .forEach(\.players, action: /Action.player) {
            VideoPlayer()
        }
    }
}
