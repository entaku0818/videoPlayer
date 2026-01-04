//
//  VideoDownloader.swift
//  videoPlayer
//
//  Created by Claude on 2024/12/30.
//

import Foundation
import Dependencies
import AVFoundation

struct VideoDownloader {
    var download: @Sendable (URL, @escaping (Double) -> Void) async throws -> URL
}

extension VideoDownloader: DependencyKey {
    static let liveValue = VideoDownloader { url, progressHandler in
        let urlString = url.absoluteString.lowercased()

        // HLSストリームはAVAssetDownloadURLSessionでダウンロード
        if urlString.contains(".m3u8") || urlString.contains("m3u8") {
            return try await downloadHLSWithAVAsset(url: url, progressHandler: progressHandler)
        }

        // DASHストリームも未対応
        if urlString.contains(".mpd") {
            throw DownloadError.dashNotSupported
        }

        // 通常のダウンロード
        return try await downloadDirect(url: url, progressHandler: progressHandler)
    }
}

// MARK: - Direct Download

private func downloadDirect(url: URL, progressHandler: @escaping (Double) -> Void) async throws -> URL {
    let sessionConfig = URLSessionConfiguration.default
    let session = URLSession(configuration: sessionConfig)

    let (tempURL, response) = try await session.download(from: url, delegate: nil)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw DownloadError.invalidResponse
    }

    // Content-Typeを確認
    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

    // Documents ディレクトリに保存
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    // ファイル名を決定
    var fileName = url.lastPathComponent
    if fileName.isEmpty || !fileName.contains(".") {
        let ext = extensionFromContentType(contentType)
        fileName = "\(UUID().uuidString).\(ext)"
    }

    let pathExtension = (fileName as NSString).pathExtension
    if pathExtension.isEmpty {
        fileName = "\(fileName).mp4"
    }

    let destinationURL = documentsURL.appendingPathComponent(fileName)

    if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
    }

    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

    // ファイルサイズを確認
    let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
    let fileSize = attributes[.size] as? Int64 ?? 0
    if fileSize < 1000 {
        try FileManager.default.removeItem(at: destinationURL)
        throw DownloadError.notAVideo
    }

    return destinationURL
}

// MARK: - HLS Download with AVAssetDownloadURLSession

// ダウンロード中のマネージャーを保持するための変数
private var activeHLSDownloadManager: HLSDownloadManager?

private func downloadHLSWithAVAsset(url: URL, progressHandler: @escaping (Double) -> Void) async throws -> URL {
    return try await withCheckedThrowingContinuation { continuation in
        let downloadManager = HLSDownloadManager(
            hlsURL: url,
            progressHandler: progressHandler,
            completion: { result in
                activeHLSDownloadManager = nil
                switch result {
                case .success(let localURL):
                    continuation.resume(returning: localURL)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        )
        activeHLSDownloadManager = downloadManager
        downloadManager.startDownload()
    }
}

// MARK: - HLS Download Manager

private class HLSDownloadManager: NSObject, AVAssetDownloadDelegate {
    private var downloadSession: AVAssetDownloadURLSession?
    private var downloadTask: AVAssetDownloadTask?
    private let hlsURL: URL
    private let progressHandler: (Double) -> Void
    private let completion: (Result<URL, Error>) -> Void
    private var downloadedAssetURL: URL?

    init(hlsURL: URL, progressHandler: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        self.hlsURL = hlsURL
        self.progressHandler = progressHandler
        self.completion = completion
        super.init()
    }

    func startDownload() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.videoPlayer.hlsdownload.\(UUID().uuidString)")
        downloadSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )

        let asset = AVURLAsset(url: hlsURL)

        // 利用可能な最高品質でダウンロード
        guard let task = downloadSession?.makeAssetDownloadTask(
            asset: asset,
            assetTitle: "HLS Video",
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 0]
        ) else {
            completion(.failure(DownloadError.downloadFailed("ダウンロードタスクを作成できませんでした")))
            return
        }

        downloadTask = task
        task.resume()
    }

    // MARK: - AVAssetDownloadDelegate

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        downloadedAssetURL = location
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            percentComplete += CMTimeGetSeconds(loadedTimeRange.duration) / CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        }
        progressHandler(min(percentComplete, 1.0))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completion(.failure(DownloadError.downloadFailed(error.localizedDescription)))
            return
        }

        guard let assetURL = downloadedAssetURL else {
            completion(.failure(DownloadError.downloadFailed("ダウンロード先が見つかりません")))
            return
        }

        // .movpkgファイルをDocumentsディレクトリに移動
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "\(UUID().uuidString).movpkg"
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: assetURL, to: destinationURL)
            completion(.success(destinationURL))
        } catch {
            completion(.failure(DownloadError.downloadFailed("ファイルの移動に失敗: \(error.localizedDescription)")))
        }
    }
}

private func extensionFromContentType(_ contentType: String) -> String {
    if contentType.contains("mp4") { return "mp4" }
    if contentType.contains("webm") { return "webm" }
    if contentType.contains("quicktime") { return "mov" }
    if contentType.contains("mpeg") { return "mpeg" }
    if contentType.contains("avi") { return "avi" }
    return "mp4" // デフォルト
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
    case hlsNotSupported
    case hlsParseError
    case hlsNoSegments
    case dashNotSupported
    case notAVideo

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        case .invalidURL:
            return "URLが無効です"
        case .downloadFailed(let message):
            return "ダウンロード失敗: \(message)"
        case .hlsNotSupported:
            return "HLSストリーム(.m3u8)は直接ダウンロードできません。ストリーム再生をお使いください。"
        case .hlsParseError:
            return "HLSプレイリストの解析に失敗しました"
        case .hlsNoSegments:
            return "HLSセグメントが見つかりませんでした（暗号化されているか、マスタープレイリストの可能性があります）"
        case .dashNotSupported:
            return "DASHストリーム(.mpd)は直接ダウンロードできません。ストリーム再生をお使いください。"
        case .notAVideo:
            return "このURLは動画ファイルではありません"
        }
    }
}
