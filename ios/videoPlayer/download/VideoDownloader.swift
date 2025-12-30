//
//  VideoDownloader.swift
//  videoPlayer
//
//  Created by Claude on 2024/12/30.
//

import Foundation
import Dependencies

struct VideoDownloader {
    var download: @Sendable (URL, @escaping (Double) -> Void) async throws -> URL
}

extension VideoDownloader: DependencyKey {
    static let liveValue = VideoDownloader { url, progressHandler in
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)

        let (tempURL, response) = try await session.download(from: url, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.invalidResponse
        }

        // Documents ディレクトリに保存
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = url.lastPathComponent.isEmpty ? "\(UUID().uuidString).mp4" : url.lastPathComponent
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        // 既存ファイルがあれば削除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }
}

extension DependencyValues {
    var videoDownloader: VideoDownloader {
        get { self[VideoDownloader.self] }
        set { self[VideoDownloader.self] = newValue }
    }
}

enum DownloadError: Error, LocalizedError {
    case invalidResponse
    case invalidURL
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        case .invalidURL:
            return "URLが無効です"
        case .downloadFailed(let message):
            return "ダウンロード失敗: \(message)"
        }
    }
}
