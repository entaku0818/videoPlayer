//
//  M3UParser.swift
//  videoPlayer
//
//  ユーザー自身が用意した M3U/M3U8 プレイリストを解析する。
//  アプリはチャンネル・プレイリストを一切同梱しない。
//

import Foundation

struct IPTVChannel: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var url: String
    var logoURL: String?
    var group: String?
    var tvgID: String?
}

struct M3UPlaylistContent: Equatable {
    var epgURL: String?
    var channels: [IPTVChannel]
}

enum M3UParseError: Error, Equatable, LocalizedError {
    case noChannels

    var errorDescription: String? {
        switch self {
        case .noChannels:
            return "プレイリストにチャンネルが見つかりませんでした。M3U/M3U8 形式か確認してください。"
        }
    }
}

enum M3UParser {
    static func parse(_ text: String) throws -> M3UPlaylistContent {
        var epgURL: String?
        var channels: [IPTVChannel] = []
        var pendingInfo: (name: String, attributes: [String: String])?
        var pendingGroup: String?
        var usedIDs: [String: Int] = [:]

        let lines = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTM3U") {
                let attributes = parseAttributes(String(line.dropFirst("#EXTM3U".count)))
                epgURL = attributes["url-tvg"] ?? attributes["x-tvg-url"]
                if let first = epgURL?.split(separator: ",").first {
                    epgURL = String(first).trimmingCharacters(in: .whitespaces)
                }
            } else if line.hasPrefix("#EXTINF:") {
                pendingInfo = parseExtInf(String(line.dropFirst("#EXTINF:".count)))
            } else if line.hasPrefix("#EXTGRP:") {
                pendingGroup = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("#") {
                continue
            } else if isStreamURL(line) {
                let attributes = pendingInfo?.attributes ?? [:]
                let infoName = pendingInfo?.name ?? ""
                let name = !infoName.isEmpty ? infoName : (attributes["tvg-name"] ?? fallbackName(for: line))
                let tvgID = attributes["tvg-id"].flatMap { $0.isEmpty ? nil : $0 }
                let group = (attributes["group-title"] ?? pendingGroup).flatMap { $0.isEmpty ? nil : $0 }
                let logo = attributes["tvg-logo"].flatMap { $0.isEmpty ? nil : $0 }

                let baseID = "\(tvgID ?? "")|\(line)"
                let count = usedIDs[baseID, default: 0]
                usedIDs[baseID] = count + 1
                let id = count == 0 ? baseID : "\(baseID)#\(count)"

                channels.append(IPTVChannel(id: id, name: name, url: line, logoURL: logo, group: group, tvgID: tvgID))
                pendingInfo = nil
                pendingGroup = nil
            }
        }

        guard !channels.isEmpty else { throw M3UParseError.noChannels }
        return M3UPlaylistContent(epgURL: epgURL, channels: channels)
    }

    /// `-1 tvg-id="a" group-title="News, JP",Channel Name` を属性とチャンネル名に分解する。
    /// 属性値の中のカンマで名前を切らないよう、引用符の外にある最初のカンマを区切りとする。
    static func parseExtInf(_ body: String) -> (name: String, attributes: [String: String]) {
        var inQuotes = false
        var splitIndex: String.Index?
        for index in body.indices {
            let char = body[index]
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                splitIndex = index
                break
            }
        }
        guard let splitIndex else {
            return ("", parseAttributes(body))
        }
        let attributePart = String(body[..<splitIndex])
        let name = String(body[body.index(after: splitIndex)...]).trimmingCharacters(in: .whitespaces)
        return (name, parseAttributes(attributePart))
    }

    static func parseAttributes(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"([A-Za-z0-9_-]+)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text) else { continue }
            result[text[keyRange].lowercased()] = String(text[valueRange])
        }
        return result
    }

    private static func isStreamURL(_ line: String) -> Bool {
        guard let url = URL(string: line), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "rtmp", "rtsp", "file"].contains(scheme)
    }

    private static func fallbackName(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let last = url.deletingPathExtension().lastPathComponent
        return last.isEmpty || last == "/" ? (url.host ?? urlString) : last
    }
}
