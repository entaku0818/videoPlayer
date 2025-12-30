//
//  WebBrowserView.swift
//  videoPlayer
//
//  Created by Claude on 2024/12/30.
//

import SwiftUI
import WebKit
import ComposableArchitecture

struct WebBrowserView: View {
    @Bindable var store: StoreOf<WebBrowser>

    var body: some View {
        VStack(spacing: 0) {
            // URL・検索入力バー
            HStack {
                TextField("検索またはURLを入力", text: $store.urlString)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.webSearch)
                    .onSubmit {
                        store.send(.goButtonTapped)
                    }

                Button {
                    store.send(.goButtonTapped)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // WebView
            ZStack {
                WebViewRepresentable(store: store)

                if store.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }

            // 検出した動画一覧（下部シート風）
            if store.showVideoList && !store.detectedVideos.isEmpty {
                VStack(spacing: 0) {
                    // ハンドル
                    HStack {
                        Text("検出した動画: \(store.detectedVideos.count)件")
                            .font(.headline)
                        Spacer()
                        Button {
                            store.send(.toggleVideoList)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(store.detectedVideos) { video in
                                VideoItemRow(
                                    video: video,
                                    isDownloading: store.downloadingVideoURL == video.src,
                                    progress: store.downloadProgress
                                ) {
                                    store.send(.downloadVideo(video.src))
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color(.systemBackground))
                .shadow(radius: 5)
            }

            // 動画検出ボタン（フローティング）
            if !store.detectedVideos.isEmpty && !store.showVideoList {
                HStack {
                    Spacer()
                    Button {
                        store.send(.toggleVideoList)
                    } label: {
                        HStack {
                            Image(systemName: "film")
                            Text("\(store.detectedVideos.count)")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(radius: 3)
                    }
                    .padding()
                }
            }
            // ストリーム検出ボタン（フローティング）
            if !store.detectedStreams.isEmpty {
                HStack {
                    Button {
                        if let firstStream = store.detectedStreams.first {
                            store.send(.playStream(firstStream.url))
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("ストリーム再生 (\(store.detectedStreams.count))")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(radius: 3)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("ブラウザ")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "エラー",
            isPresented: .constant(store.errorMessage != nil),
            actions: {
                Button("OK") {
                    store.send(.clearError)
                }
            },
            message: {
                Text(store.errorMessage ?? "")
            }
        )
        .fullScreenCover(isPresented: .constant(store.showStreamPlayer)) {
            if let streamURL = store.selectedStreamURL {
                FullscreenStreamPlayerView(streamURL: streamURL)
                    .onDisappear {
                        store.send(.closeStreamPlayer)
                    }
            }
        }
    }
}

struct VideoItemRow: View {
    let video: WebBrowser.State.DetectedVideo
    let isDownloading: Bool
    let progress: Double
    let onDownload: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.src)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                if let type = video.type {
                    Text(type)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isDownloading {
                ProgressView(value: progress)
                    .frame(width: 60)
            } else {
                Button {
                    onDownload()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - WKWebView Representable

struct WebViewRepresentable: UIViewRepresentable {
    let store: StoreOf<WebBrowser>

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // JavaScript でビデオタグを検出するスクリプトを注入
        let videoScript = WKUserScript(
            source: videoDetectionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(videoScript)
        webView.configuration.userContentController.add(
            context.coordinator,
            name: "videoDetector"
        )

        // ストリームURL検出用スクリプト
        let streamScript = WKUserScript(
            source: streamDetectionScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(streamScript)
        webView.configuration.userContentController.add(
            context.coordinator,
            name: "streamDetector"
        )

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = store.currentURL,
           webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let store: StoreOf<WebBrowser>

        init(store: StoreOf<WebBrowser>) {
            self.store = store
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // ページ読み込み開始
        }

        // ユニバーサルリンク（他アプリへの遷移）を防ぐ
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // 常にブラウザ内で開く（外部アプリに飛ばさない）
            decisionHandler(.allow, preferences)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // ナビゲーション確定時にURLバーを更新（ストリームはリセットしない）
            if let url = webView.url {
                store.send(.updateURLBar(url))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            store.send(.pageLoaded)

            // ページ読み込み完了後にビデオを検出
            webView.evaluateJavaScript("detectVideos()") { _, error in
                if let error = error {
                    print("Video detection error: \(error)")
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            store.send(.pageLoaded)
        }

        // JavaScript からのメッセージを受信
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoDetector" {
                guard let body = message.body as? [[String: Any]] else { return }

                let videos = body.compactMap { dict -> WebBrowser.State.DetectedVideo? in
                    guard let src = dict["src"] as? String, !src.isEmpty else {
                        return nil
                    }
                    return WebBrowser.State.DetectedVideo(
                        src: src,
                        poster: dict["poster"] as? String,
                        type: dict["type"] as? String
                    )
                }

                store.send(.videosDetected(videos))
            } else if message.name == "streamDetector" {
                guard let body = message.body as? [[String: Any]] else { return }

                let streams = body.compactMap { dict -> WebBrowser.State.DetectedStream? in
                    guard let url = dict["url"] as? String, !url.isEmpty else {
                        return nil
                    }
                    let typeString = dict["type"] as? String ?? ""
                    let streamType: WebBrowser.State.DetectedStream.StreamType
                    switch typeString {
                    case "hls":
                        streamType = .hls
                    case "dash":
                        streamType = .dash
                    default:
                        streamType = .mp4
                    }
                    return WebBrowser.State.DetectedStream(url: url, type: streamType)
                }

                if !streams.isEmpty {
                    store.send(.streamsDetected(streams))
                }
            }
        }
    }
}

// MARK: - JavaScript for Video Detection

private let videoDetectionScript = """
function detectVideos() {
    var videos = [];

    // <video> タグを検出
    document.querySelectorAll('video').forEach(function(video) {
        var src = video.src || video.currentSrc;

        // <source> タグもチェック
        if (!src) {
            var source = video.querySelector('source');
            if (source) {
                src = source.src;
            }
        }

        if (src) {
            videos.push({
                src: src,
                poster: video.poster || null,
                type: video.type || getVideoType(src)
            });
        }
    });

    // <source> タグを直接検出
    document.querySelectorAll('source[type^="video"]').forEach(function(source) {
        var src = source.src;
        if (src && !videos.some(v => v.src === src)) {
            videos.push({
                src: src,
                poster: null,
                type: source.type || getVideoType(src)
            });
        }
    });

    // blob URL や data URL を除外、mp4/webm などの直接リンクを含める
    videos = videos.filter(function(v) {
        return v.src && !v.src.startsWith('blob:') && !v.src.startsWith('data:');
    });

    // 重複を除去
    var uniqueVideos = [];
    var seen = {};
    videos.forEach(function(v) {
        if (!seen[v.src]) {
            seen[v.src] = true;
            uniqueVideos.push(v);
        }
    });

    window.webkit.messageHandlers.videoDetector.postMessage(uniqueVideos);
    return uniqueVideos;
}

function getVideoType(src) {
    if (src.includes('.mp4')) return 'video/mp4';
    if (src.includes('.webm')) return 'video/webm';
    if (src.includes('.ogg')) return 'video/ogg';
    if (src.includes('.mov')) return 'video/quicktime';
    if (src.includes('.m3u8')) return 'application/x-mpegURL';
    return 'video/unknown';
}

// MutationObserver で動的に追加された動画も検出
var observer = new MutationObserver(function(mutations) {
    detectVideos();
});

observer.observe(document.body, {
    childList: true,
    subtree: true
});
"""

// MARK: - JavaScript for Stream Detection

private let streamDetectionScript = """
(function() {
    var detectedStreams = [];
    var sentStreams = new Set();

    function isStreamURL(url) {
        if (!url || typeof url !== 'string') return null;
        url = url.toLowerCase();

        if (url.includes('.m3u8') || url.includes('m3u8')) {
            return 'hls';
        }
        if (url.includes('.mpd') || url.includes('dash')) {
            return 'dash';
        }
        if (url.includes('.mp4') && (url.includes('video') || url.includes('media'))) {
            return 'mp4';
        }
        return null;
    }

    function reportStream(url, type) {
        if (sentStreams.has(url)) return;
        sentStreams.add(url);

        try {
            window.webkit.messageHandlers.streamDetector.postMessage([{
                url: url,
                type: type
            }]);
        } catch(e) {}
    }

    // XMLHttpRequest をフック
    var originalXHROpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
        var streamType = isStreamURL(url);
        if (streamType) {
            reportStream(url, streamType);
        }
        return originalXHROpen.apply(this, arguments);
    };

    // fetch をフック
    var originalFetch = window.fetch;
    window.fetch = function(input, init) {
        var url = typeof input === 'string' ? input : (input.url || '');
        var streamType = isStreamURL(url);
        if (streamType) {
            reportStream(url, streamType);
        }
        return originalFetch.apply(this, arguments);
    };

    // video/source タグの src 属性を監視
    function checkVideoSources() {
        document.querySelectorAll('video source, video').forEach(function(el) {
            var src = el.src || el.getAttribute('src');
            if (src) {
                var streamType = isStreamURL(src);
                if (streamType) {
                    reportStream(src, streamType);
                }
            }
        });
    }

    // ページ読み込み後にチェック
    if (document.readyState === 'complete') {
        checkVideoSources();
    } else {
        window.addEventListener('load', checkVideoSources);
    }

    // DOM変更を監視
    var observer = new MutationObserver(function(mutations) {
        checkVideoSources();
    });

    if (document.body) {
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['src']
        });
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            observer.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['src']
            });
        });
    }
})();
"""

#Preview {
    NavigationStack {
        WebBrowserView(
            store: Store(
                initialState: WebBrowser.State(),
                reducer: { WebBrowser() }
            )
        )
    }
}
