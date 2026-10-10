//
//  IPTVFeatureTests.swift
//  videoPlayerTests
//
//  fixture は全てダミー（予約ドメイン example.com）。実在の配信URLは使わない。
//

import XCTest
import ComposableArchitecture
@testable import videoPlayer

@MainActor
final class IPTVPlaylistListTests: XCTestCase {

    private static let fixture = """
    #EXTM3U url-tvg="https://example.com/epg.xml"
    #EXTINF:-1 tvg-id="a" group-title="News",Alpha
    https://example.com/a.m3u8
    #EXTINF:-1 group-title="Sports",Beta
    https://example.com/b.m3u8
    """

    private static let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testAddFromURLParsesAndSaves() async throws {
        let saved = LockIsolated<[IPTVPlaylist]>([])
        let store = TestStore(initialState: IPTVPlaylistList.State()) {
            IPTVPlaylistList()
        } withDependencies: {
            $0.iptvClient.fetchPlaylistText = { url in
                XCTAssertEqual(url.absoluteString, "https://example.com/list.m3u")
                return Self.fixture
            }
            $0.iptvClient.savePlaylists = { saved.setValue($0) }
            $0.uuid = .incrementing
            $0.date.now = Self.date
        }
        store.exhaustivity = .off

        await store.send(.addButtonTapped) {
            $0.isShowingAddSheet = true
        }
        await store.send(.binding(.set(\.urlInput, " https://example.com/list.m3u "))) {
            $0.urlInput = " https://example.com/list.m3u "
        }
        await store.send(.addFromURLTapped) {
            $0.isImporting = true
        }
        await store.receive(\.playlistImported) {
            $0.isImporting = false
            $0.isShowingAddSheet = false
            XCTAssertEqual($0.playlists.count, 1)
        }
        await store.finish()

        let playlist = try XCTUnwrap(store.state.playlists.first)
        XCTAssertEqual(playlist.name, "example.com")
        XCTAssertEqual(playlist.sourceURL, "https://example.com/list.m3u")
        XCTAssertEqual(playlist.epgURL, "https://example.com/epg.xml")
        XCTAssertEqual(playlist.channels.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(playlist.addedAt, Self.date)
        XCTAssertEqual(saved.value, [playlist])
    }

    func testInvalidURLShowsErrorWithoutFetching() async {
        let store = TestStore(initialState: IPTVPlaylistList.State(urlInput: "ftp://example.com/x.m3u")) {
            IPTVPlaylistList()
        }

        await store.send(.addFromURLTapped) {
            $0.errorMessage = IPTVClientError.invalidURL.localizedDescription
        }
    }

    func testImportFailureKeepsSheetOpenWithError() async {
        let store = TestStore(
            initialState: IPTVPlaylistList.State(isShowingAddSheet: true, urlInput: "https://example.com/empty.m3u")
        ) {
            IPTVPlaylistList()
        } withDependencies: {
            $0.iptvClient.fetchPlaylistText = { _ in "#EXTM3U\n" }
        }

        await store.send(.addFromURLTapped) {
            $0.isImporting = true
        }
        await store.receive(\.playlistImported) {
            $0.isImporting = false
            $0.errorMessage = M3UParseError.noChannels.localizedDescription
        }
        XCTAssertTrue(store.state.isShowingAddSheet)
    }

    func testFileImportUsesNameInputAndHasNoSourceURL() async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/my_channels.m3u")
        let store = TestStore(initialState: IPTVPlaylistList.State(nameInput: "家のリスト")) {
            IPTVPlaylistList()
        } withDependencies: {
            $0.iptvClient.fetchPlaylistText = { _ in Self.fixture }
            $0.iptvClient.savePlaylists = { _ in }
            $0.uuid = .incrementing
            $0.date.now = Self.date
        }
        store.exhaustivity = .off

        await store.send(.fileSelected(.success(fileURL)))
        await store.receive(\.playlistImported)
        await store.finish()

        let playlist = try XCTUnwrap(store.state.playlists.first)
        XCTAssertEqual(playlist.name, "家のリスト")
        XCTAssertNil(playlist.sourceURL)
    }

    func testOnAppearLoadsAndDeleteSaves() async {
        let playlist = IPTVPlaylist(
            id: UUID(0), name: "L", sourceURL: nil, epgURL: nil,
            channels: [], addedAt: Self.date, updatedAt: Self.date
        )
        let saved = LockIsolated<[IPTVPlaylist]?>(nil)
        let store = TestStore(initialState: IPTVPlaylistList.State()) {
            IPTVPlaylistList()
        } withDependencies: {
            $0.iptvClient.loadPlaylists = { [playlist] }
            $0.iptvClient.savePlaylists = { saved.setValue($0) }
        }

        await store.send(.onAppear)
        await store.receive(\.playlistsLoaded) {
            $0.playlists = [playlist]
        }
        await store.send(.deletePlaylists(IndexSet(integer: 0))) {
            $0.playlists = []
        }
        await store.finish()
        XCTAssertEqual(saved.value, [])
    }

    func testRefreshReplacesChannels() async {
        let playlist = IPTVPlaylist(
            id: UUID(0), name: "L", sourceURL: "https://example.com/list.m3u", epgURL: nil,
            channels: [], addedAt: Self.date, updatedAt: Self.date
        )
        let later = Self.date.addingTimeInterval(60)
        let store = TestStore(initialState: IPTVPlaylistList.State(playlists: [playlist])) {
            IPTVPlaylistList()
        } withDependencies: {
            $0.iptvClient.fetchPlaylistText = { _ in Self.fixture }
            $0.iptvClient.savePlaylists = { _ in }
            $0.date.now = later
        }
        store.exhaustivity = .off

        await store.send(.refreshPlaylist(UUID(0))) {
            $0.refreshingPlaylistID = UUID(0)
        }
        await store.receive(\.playlistRefreshed) {
            $0.refreshingPlaylistID = nil
            $0.playlists[id: UUID(0)]?.updatedAt = later
        }
        XCTAssertEqual(store.state.playlists[id: UUID(0)]?.channels.count, 2)
    }

    func testPlaylistTapOpensChannelList() async {
        let channel = IPTVChannel(id: "1", name: "A", url: "https://example.com/a.m3u8", logoURL: nil, group: nil, tvgID: nil)
        let playlist = IPTVPlaylist(
            id: UUID(0), name: "L", sourceURL: nil, epgURL: nil,
            channels: [channel], addedAt: Self.date, updatedAt: Self.date
        )
        let store = TestStore(initialState: IPTVPlaylistList.State(playlists: [playlist])) {
            IPTVPlaylistList()
        }

        await store.send(.playlistTapped(UUID(0))) {
            $0.channelList = IPTVChannelList.State(playlistName: "L", channels: [channel])
        }
    }
}

@MainActor
final class IPTVChannelListTests: XCTestCase {

    private let channels = [
        IPTVChannel(id: "1", name: "News One", url: "https://example.com/1.m3u8", logoURL: nil, group: "News", tvgID: nil),
        IPTVChannel(id: "2", name: "Sports A", url: "https://example.com/2.m3u8", logoURL: nil, group: "Sports", tvgID: nil),
        IPTVChannel(id: "3", name: "Misc", url: "https://example.com/3.m3u8", logoURL: nil, group: nil, tvgID: nil),
        IPTVChannel(id: "4", name: "News Two", url: "https://example.com/4.m3u8", logoURL: nil, group: "News", tvgID: nil)
    ]

    func testGroupsKeepPlaylistOrder() {
        let state = IPTVChannelList.State(playlistName: "L", channels: channels)

        XCTAssertEqual(state.groups, ["News", "Sports", IPTVChannelList.State.ungroupedTitle])
        XCTAssertEqual(state.sections.map(\.title), ["News", "Sports", IPTVChannelList.State.ungroupedTitle])
        XCTAssertEqual(state.sections.first?.channels.map(\.id), ["1", "4"])
    }

    func testSearchAndGroupFilter() async {
        let store = TestStore(initialState: IPTVChannelList.State(playlistName: "L", channels: channels)) {
            IPTVChannelList()
        }

        await store.send(.binding(.set(\.searchText, "news"))) {
            $0.searchText = "news"
        }
        XCTAssertEqual(store.state.filteredChannels.map(\.id), ["1", "4"])

        await store.send(.binding(.set(\.searchText, ""))) {
            $0.searchText = ""
        }
        await store.send(.groupSelected(IPTVChannelList.State.ungroupedTitle)) {
            $0.selectedGroup = IPTVChannelList.State.ungroupedTitle
        }
        XCTAssertEqual(store.state.filteredChannels.map(\.id), ["3"])
    }

    func testChannelTapStartsAndDismissStopsPlayback() async {
        let store = TestStore(initialState: IPTVChannelList.State(playlistName: "L", channels: channels)) {
            IPTVChannelList()
        }

        await store.send(.channelTapped(channels[1])) {
            $0.playingChannel = self.channels[1]
        }
        await store.send(.playerDismissed) {
            $0.playingChannel = nil
        }
    }
}
