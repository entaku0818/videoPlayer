//
//  IPTVClient.swift
//  videoPlayer
//
//  ユーザーが登録した M3U プレイリストの取得・永続化。
//  プレイリストは Application Support 配下の JSON に保存する（CoreData のマイグレーションを避けるため）。
//

import Foundation
import Dependencies

struct IPTVPlaylist: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    /// URL から登録した場合のみ保持（ファイル読込の場合は nil）
    var sourceURL: String?
    var epgURL: String?
    var channels: [IPTVChannel]
    var addedAt: Date
    var updatedAt: Date
}

struct IPTVPlaylistStore {
    let fileURL: URL

    static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("iptv_playlists.json")
    }

    func load() throws -> [IPTVPlaylist] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode([IPTVPlaylist].self, from: data)
    }

    func save(_ playlists: [IPTVPlaylist]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(playlists)
        try data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum IPTVClientError: Error, Equatable, LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case unreadableText

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URLが正しくありません。"
        case let .httpStatus(code):
            return "プレイリストを取得できませんでした（HTTP \(code)）。"
        case .unreadableText:
            return "プレイリストをテキストとして読み込めませんでした。"
        }
    }
}

struct IPTVClient {
    var fetchPlaylistText: @Sendable (URL) async throws -> String
    var loadPlaylists: @Sendable () async throws -> [IPTVPlaylist]
    var savePlaylists: @Sendable ([IPTVPlaylist]) async throws -> Void
}

extension IPTVClient {
    static func decodeText(_ data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        throw IPTVClientError.unreadableText
    }
}

extension IPTVClient: DependencyKey {
    static let liveValue: IPTVClient = {
        let store = IPTVPlaylistStore(fileURL: IPTVPlaylistStore.defaultFileURL)
        return IPTVClient(
            fetchPlaylistText: { url in
                if url.isFileURL {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    return try decodeText(Data(contentsOf: url))
                }
                guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
                    throw IPTVClientError.invalidURL
                }
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw IPTVClientError.httpStatus(http.statusCode)
                }
                return try decodeText(data)
            },
            loadPlaylists: { try store.load() },
            savePlaylists: { try store.save($0) }
        )
    }()

    static let previewValue = IPTVClient(
        fetchPlaylistText: { _ in "#EXTM3U\n" },
        loadPlaylists: { [] },
        savePlaylists: { _ in }
    )

    static let testValue = IPTVClient(
        fetchPlaylistText: unimplemented("IPTVClient.fetchPlaylistText", placeholder: ""),
        loadPlaylists: unimplemented("IPTVClient.loadPlaylists", placeholder: []),
        savePlaylists: unimplemented("IPTVClient.savePlaylists")
    )
}

extension DependencyValues {
    var iptvClient: IPTVClient {
        get { self[IPTVClient.self] }
        set { self[IPTVClient.self] = newValue }
    }
}
