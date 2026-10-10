//
//  IPTVChannelList.swift
//  videoPlayer
//
//  プレイリスト内のチャンネル一覧（グループ別・検索）と再生対象の選択。
//

import Foundation
import ComposableArchitecture

@Reducer
struct IPTVChannelList {
    @ObservableState
    struct State: Equatable {
        var playlistName: String
        var channels: [IPTVChannel]
        var searchText = ""
        /// nil = すべてのグループ
        var selectedGroup: String?
        var playingChannel: IPTVChannel?

        static let ungroupedTitle = "未分類"

        /// プレイリスト内の出現順を保ったグループ名一覧
        var groups: [String] {
            var seen = Set<String>()
            return channels.compactMap { channel in
                let group = channel.group ?? Self.ungroupedTitle
                return seen.insert(group).inserted ? group : nil
            }
        }

        var filteredChannels: [IPTVChannel] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return channels.filter { channel in
                if let selectedGroup, (channel.group ?? Self.ungroupedTitle) != selectedGroup {
                    return false
                }
                if query.isEmpty { return true }
                return channel.name.localizedCaseInsensitiveContains(query)
                    || (channel.group?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        /// 表示用セクション（グループ順）
        var sections: [Section] {
            let filtered = filteredChannels
            let grouped = Dictionary(grouping: filtered) { $0.group ?? Self.ungroupedTitle }
            return groups.compactMap { group in
                guard let channels = grouped[group], !channels.isEmpty else { return nil }
                return Section(title: group, channels: channels)
            }
        }

        struct Section: Equatable, Identifiable {
            var title: String
            var channels: [IPTVChannel]
            var id: String { title }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case groupSelected(String?)
        case channelTapped(IPTVChannel)
        case playerDismissed
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .groupSelected(group):
                state.selectedGroup = group
                return .none

            case let .channelTapped(channel):
                state.playingChannel = channel
                return .none

            case .playerDismissed:
                state.playingChannel = nil
                return .none
            }
        }
    }
}
