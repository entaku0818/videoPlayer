//
//  IPTVPlaylistList.swift
//  videoPlayer
//
//  ユーザーが登録した M3U プレイリストの一覧・追加（URL/ファイル）・更新・削除。
//

import Foundation
import ComposableArchitecture

@Reducer
struct IPTVPlaylistList {
    @ObservableState
    struct State: Equatable {
        var playlists: IdentifiedArrayOf<IPTVPlaylist> = []
        var isShowingAddSheet = false
        var isShowingFileImporter = false
        var nameInput = ""
        var urlInput = ""
        var isImporting = false
        var errorMessage: String?
        var refreshingPlaylistID: UUID?
        @Presents var channelList: IPTVChannelList.State?
    }

    enum Source: Equatable {
        case url(URL)
        case file(URL)
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case playlistsLoaded(Result<[IPTVPlaylist], Error>)
        case addButtonTapped
        case addSheetDismissed
        case addFromURLTapped
        case importFileTapped
        case fileSelected(Result<URL, Error>)
        case playlistImported(Result<M3UPlaylistContent, Error>, name: String, source: Source)
        case refreshPlaylist(UUID)
        case playlistRefreshed(UUID, Result<M3UPlaylistContent, Error>)
        case deletePlaylists(IndexSet)
        case playlistTapped(UUID)
        case channelList(PresentationAction<IPTVChannelList.Action>)
        case errorDismissed
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { send in
                    await send(.playlistsLoaded(Result { try await iptvClient.loadPlaylists() }))
                }

            case let .playlistsLoaded(.success(playlists)):
                state.playlists = IdentifiedArray(uniqueElements: playlists)
                return .none

            case let .playlistsLoaded(.failure(error)):
                state.errorMessage = "プレイリストの読み込みに失敗しました: \(error.localizedDescription)"
                return .none

            case .addButtonTapped:
                state.nameInput = ""
                state.urlInput = ""
                state.isShowingAddSheet = true
                return .none

            case .addSheetDismissed:
                state.isShowingAddSheet = false
                return .none

            case .addFromURLTapped:
                let trimmed = state.urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: trimmed),
                      let scheme = url.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      url.host != nil else {
                    state.errorMessage = IPTVClientError.invalidURL.localizedDescription
                    return .none
                }
                let name = Self.resolveName(state.nameInput, fallbackURL: url)
                return importPlaylist(state: &state, source: .url(url), name: name)

            case .importFileTapped:
                state.isShowingFileImporter = true
                return .none

            case let .fileSelected(.success(url)):
                state.isShowingFileImporter = false
                let name = Self.resolveName(state.nameInput, fallbackURL: url)
                return importPlaylist(state: &state, source: .file(url), name: name)

            case let .fileSelected(.failure(error)):
                state.isShowingFileImporter = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .playlistImported(.success(content), name, source):
                state.isImporting = false
                state.isShowingAddSheet = false
                let date = now
                var sourceURL: String?
                if case let .url(url) = source { sourceURL = url.absoluteString }
                let playlist = IPTVPlaylist(
                    id: uuid(),
                    name: name,
                    sourceURL: sourceURL,
                    epgURL: content.epgURL,
                    channels: content.channels,
                    addedAt: date,
                    updatedAt: date
                )
                state.playlists.append(playlist)
                return save(state.playlists)

            case let .playlistImported(.failure(error), _, _):
                state.isImporting = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .refreshPlaylist(id):
                guard let playlist = state.playlists[id: id],
                      let sourceURL = playlist.sourceURL,
                      let url = URL(string: sourceURL) else { return .none }
                state.refreshingPlaylistID = id
                return .run { send in
                    await send(.playlistRefreshed(id, Result {
                        try M3UParser.parse(try await iptvClient.fetchPlaylistText(url))
                    }))
                }

            case let .playlistRefreshed(id, .success(content)):
                state.refreshingPlaylistID = nil
                state.playlists[id: id]?.channels = content.channels
                state.playlists[id: id]?.epgURL = content.epgURL
                state.playlists[id: id]?.updatedAt = now
                return save(state.playlists)

            case let .playlistRefreshed(_, .failure(error)):
                state.refreshingPlaylistID = nil
                state.errorMessage = error.localizedDescription
                return .none

            case let .deletePlaylists(offsets):
                state.playlists.remove(atOffsets: offsets)
                return save(state.playlists)

            case let .playlistTapped(id):
                guard let playlist = state.playlists[id: id] else { return .none }
                state.channelList = IPTVChannelList.State(playlistName: playlist.name, channels: playlist.channels)
                return .none

            case .channelList:
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none
            }
        }
        .ifLet(\.$channelList, action: \.channelList) {
            IPTVChannelList()
        }
    }

    private func importPlaylist(state: inout State, source: Source, name: String) -> Effect<Action> {
        state.isImporting = true
        return .run { send in
            let url: URL
            switch source {
            case let .url(value), let .file(value):
                url = value
            }
            await send(.playlistImported(
                Result { try M3UParser.parse(try await iptvClient.fetchPlaylistText(url)) },
                name: name,
                source: source
            ))
        }
    }

    private func save(_ playlists: IdentifiedArrayOf<IPTVPlaylist>) -> Effect<Action> {
        let snapshot = Array(playlists)
        return .run { send in
            do {
                try await iptvClient.savePlaylists(snapshot)
            } catch {
                await send(.playlistsLoaded(.failure(error)))
            }
        }
    }

    static func resolveName(_ input: String, fallbackURL: URL) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if fallbackURL.isFileURL {
            return fallbackURL.deletingPathExtension().lastPathComponent
        }
        return fallbackURL.host ?? "プレイリスト"
    }
}
