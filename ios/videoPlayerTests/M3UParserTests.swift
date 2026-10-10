//
//  M3UParserTests.swift
//  videoPlayerTests
//
//  fixture は全てテスト内で完結するダミー（予約ドメイン example.com）。実在の配信URLは使わない。
//

import XCTest
@testable import videoPlayer

final class M3UParserTests: XCTestCase {

    func testParsesExtInfAttributesAndHeaderEPG() throws {
        let text = """
        #EXTM3U url-tvg="https://example.com/epg.xml"
        #EXTINF:-1 tvg-id="ch1" tvg-name="Channel One" tvg-logo="https://example.com/1.png" group-title="News",Channel 1
        https://example.com/live/1.m3u8
        #EXTINF:-1 tvg-id="ch2" group-title="Sports",Channel 2
        https://example.com/live/2.m3u8
        """
        let content = try M3UParser.parse(text)

        XCTAssertEqual(content.epgURL, "https://example.com/epg.xml")
        XCTAssertEqual(content.channels.count, 2)
        XCTAssertEqual(content.channels[0].name, "Channel 1")
        XCTAssertEqual(content.channels[0].tvgID, "ch1")
        XCTAssertEqual(content.channels[0].logoURL, "https://example.com/1.png")
        XCTAssertEqual(content.channels[0].group, "News")
        XCTAssertEqual(content.channels[0].url, "https://example.com/live/1.m3u8")
        XCTAssertEqual(content.channels[1].group, "Sports")
        XCTAssertNil(content.channels[1].logoURL)
    }

    func testHandlesBOMAndCRLF() throws {
        let text = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1,Alpha\r\nhttps://example.com/a.m3u8\r\n"
        let content = try M3UParser.parse(text)

        XCTAssertEqual(content.channels.map(\.name), ["Alpha"])
        XCTAssertEqual(content.channels.first?.url, "https://example.com/a.m3u8")
    }

    func testCommaInsideQuotedAttributeDoesNotSplitName() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1 group-title="News, Local",Name, With Comma
        https://example.com/a.m3u8
        """
        let channel = try XCTUnwrap(M3UParser.parse(text).channels.first)

        XCTAssertEqual(channel.group, "News, Local")
        XCTAssertEqual(channel.name, "Name, With Comma")
    }

    func testExtGrpAndXTvgURLAreSupported() throws {
        let text = """
        #EXTM3U x-tvg-url="https://example.com/a.xml,https://example.com/b.xml"
        #EXTINF:-1,Beta
        #EXTGRP:Movies
        https://example.com/b.m3u8
        """
        let content = try M3UParser.parse(text)

        XCTAssertEqual(content.epgURL, "https://example.com/a.xml")
        XCTAssertEqual(content.channels.first?.group, "Movies")
    }

    func testURLWithoutExtInfUsesFallbackNameAndSkipsUnknownTags() throws {
        let text = """
        #EXTM3U
        #EXTVLCOPT:http-user-agent=Test
        https://example.com/streams/gamma.m3u8
        not a url line
        """
        let content = try M3UParser.parse(text)

        XCTAssertEqual(content.channels.count, 1)
        XCTAssertEqual(content.channels.first?.name, "gamma")
    }

    func testDuplicateEntriesGetUniqueIDs() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1,Same
        https://example.com/same.m3u8
        #EXTINF:-1,Same
        https://example.com/same.m3u8
        """
        let channels = try M3UParser.parse(text).channels

        XCTAssertEqual(channels.count, 2)
        XCTAssertEqual(Set(channels.map(\.id)).count, 2)
    }

    func testEmptyOrNonPlaylistThrows() {
        XCTAssertThrowsError(try M3UParser.parse("#EXTM3U\n")) { error in
            XCTAssertEqual(error as? M3UParseError, .noChannels)
        }
        XCTAssertThrowsError(try M3UParser.parse("<html><body>hello</body></html>"))
    }
}

final class IPTVPlaylistStoreTests: XCTestCase {

    func testSaveAndLoadRoundTrip() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("iptv_\(UUID().uuidString)")
            .appendingPathComponent("playlists.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = IPTVPlaylistStore(fileURL: fileURL)

        XCTAssertEqual(try store.load(), [])

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let playlist = IPTVPlaylist(
            id: UUID(),
            name: "My List",
            sourceURL: "https://example.com/list.m3u",
            epgURL: nil,
            channels: [IPTVChannel(id: "1", name: "A", url: "https://example.com/a.m3u8", logoURL: nil, group: "G", tvgID: nil)],
            addedAt: date,
            updatedAt: date
        )
        try store.save([playlist])

        XCTAssertEqual(try store.load(), [playlist])
    }

    func testDecodeTextFallsBackToLatin1() throws {
        let data = Data([0x23, 0x45, 0x58, 0x54, 0xE9]) // "#EXT" + Latin-1 'é'（UTF-8 として不正）
        XCTAssertEqual(try IPTVClient.decodeText(data), "#EXTé")
    }
}
