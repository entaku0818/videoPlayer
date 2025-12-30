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
            // URL入力バー
            HStack {
                TextField("URLを入力", text: $store.urlString)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .onSubmit {
                        store.send(.goButtonTapped)
                    }

                Button("Go") {
                    store.send(.goButtonTapped)
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
        let script = WKUserScript(
            source: videoDetectionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(script)
        webView.configuration.userContentController.add(
            context.coordinator,
            name: "videoDetector"
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
            guard message.name == "videoDetector",
                  let body = message.body as? [[String: Any]] else {
                return
            }

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
