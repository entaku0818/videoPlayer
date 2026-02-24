//
//  SNSVideoPlayerView.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2026/02/24.
//

import SwiftUI
import WebKit

struct SNSVideoPlayerView: View {
    let video: VideoPlayerList.State.VideoModel
    @Environment(\.dismiss) private var dismiss

    private var embedURL: URL? {
        guard let sourceURL = video.sourceURL,
              let url = URL(string: sourceURL) else { return nil }
        switch video.videoType {
        case "youtube":
            if let id = extractYouTubeID(from: url) {
                return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1")
            }
            return url
        case "twitter":
            return url
        case "instagram":
            if let shortcode = extractInstagramShortcode(from: url) {
                return URL(string: "https://www.instagram.com/p/\(shortcode)/embed/")
            }
            return url
        default:
            return url
        }
    }

    var body: some View {
        SNSWebView(url: embedURL)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(video.title)
            .ignoresSafeArea(edges: .bottom)
    }

    private func extractYouTubeID(from url: URL) -> String? {
        // youtube.com/watch?v=ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let v = queryItems.first(where: { $0.name == "v" })?.value {
            return v
        }
        // youtu.be/ID
        if url.host?.contains("youtu.be") == true {
            let path = url.pathComponents
            return path.count > 1 ? path[1] : nil
        }
        return nil
    }

    private func extractInstagramShortcode(from url: URL) -> String? {
        let components = url.pathComponents
        // /p/SHORTCODE/ or /reel/SHORTCODE/
        if let pIndex = components.firstIndex(of: "p"), components.count > pIndex + 1 {
            return components[pIndex + 1]
        }
        if let reelIndex = components.firstIndex(of: "reel"), components.count > reelIndex + 1 {
            return components[reelIndex + 1]
        }
        return nil
    }
}

struct SNSWebView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url {
            webView.load(URLRequest(url: url))
        }
    }
}
