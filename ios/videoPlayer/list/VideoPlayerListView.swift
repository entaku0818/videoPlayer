//
//  VideoPlayerListView.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/02.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
import WebKit

struct VideoPlayerListView: View {
    let store: StoreOf<VideoPlayerList>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Group {
                    if viewStore.isLoading {
                        ProgressView()
                    } else {
                        List {
                            ForEach(viewStore.videos) { video in
                                NavigationLink {
                                    if video.isLocalVideo {
                                        VideoPlayerView(
                                            store: Store(
                                                initialState: VideoPlayer.State(
                                                    id: video.id, fileName: video.fileName
                                                ),
                                                reducer: { VideoPlayer() }
                                            )
                                        )
                                    } else {
                                        SNSVideoPlayerView(video: video)
                                    }
                                } label: {
                                    VideoRowView(video: video)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewStore.send(.deleteVideo(viewStore.videos[index]))
                                }
                            }
                        }
                        .refreshable {
                            viewStore.send(.onAppear)
                        }
                    }
                }
                .navigationTitle("Videos")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink {
                            WebBrowserView(
                                store: Store(
                                    initialState: WebBrowser.State(),
                                    reducer: { WebBrowser() }
                                )
                            )
                        } label: {
                            Image(systemName: "globe")
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button {
                                viewStore.send(.openURLInput)
                            } label: {
                                Image(systemName: "link")
                            }

                            Button {
                                viewStore.send(.openVideoPicker)
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .overlay {
                    if viewStore.isDownloading {
                        DownloadProgressOverlay(progress: viewStore.downloadProgress)
                    }
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.isShowingVideoPicker,
                        send: { _ in .closeVideoPicker }
                    )
                ) {
                    VideoPicker(store: store)
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.isShowingURLInput,
                        send: { _ in .closeURLInput }
                    )
                ) {
                    URLInputSheet(store: store)
                }
                .alert(
                    "エラー",
                    isPresented: viewStore.binding(
                        get: { $0.downloadError != nil },
                        send: { _ in .clearDownloadError }
                    ),
                    actions: {
                        Button("OK") {
                            viewStore.send(.clearDownloadError)
                        }
                    },
                    message: {
                        Text(viewStore.downloadError ?? "")
                    }
                )
            }
            .onAppear {
                viewStore.send(.onAppear)
                // 一覧画面では縦向きに戻す
                if UIDevice.current.orientation.isLandscape {
                    UIDevice.current.setValue(UIDeviceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
        }
    }
}

// MARK: - URL Input Sheet

struct URLInputSheet: View {
    let store: StoreOf<VideoPlayerList>
    @State private var urlText = ""

    private var isSNSURL: Bool {
        let lower = urlText.lowercased()
        return lower.contains("youtube.com") || lower.contains("youtu.be")
            || lower.contains("twitter.com") || lower.contains("x.com")
            || lower.contains("instagram.com")
    }

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 20) {
                    Text("動画のURLを入力")
                        .font(.headline)

                    TextField("https://example.com/video.mp4", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .padding(.horizontal)

                    if isSNSURL {
                        Text("YouTube / Twitter / Instagram のURLはダウンロードせずにリストへ追加します")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("MP4, WebM, MOV, HLS (.m3u8) などのリンクを入力してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.top, 30)
                .navigationTitle("URLから追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            viewStore.send(.closeURLInput)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isSNSURL ? "追加" : "ダウンロード") {
                            viewStore.send(.updateURLInput(urlText))
                            viewStore.send(.downloadFromURL)
                        }
                        .disabled(urlText.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Download Progress Overlay

struct DownloadProgressOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("ダウンロード中...")
                    .font(.headline)
                    .foregroundColor(.white)

                ProgressView(value: progress)
                    .frame(width: 200)
                    .tint(.white)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
    }
}



struct VideoThumbnail: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)
                    .onAppear {
                        generateThumbnail()
                    }
            }
        }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            thumbnail = UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
        }
    }
}

struct SNSThumbnailView: View {
    let video: VideoPlayerList.State.VideoModel

    private var youTubeID: String? {
        guard let sourceURL = video.sourceURL,
              let url = URL(string: sourceURL) else { return nil }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return v
        }
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.count > 1 ? url.pathComponents[1] : nil
        }
        return nil
    }

    var body: some View {
        ZStack {
            if video.videoType == "youtube", let id = youTubeID,
               let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg") {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    youTubePlaceholder
                }
            } else {
                snsIconPlaceholder
            }
        }
        .frame(width: 120, height: 80)
        .cornerRadius(8)
        .clipped()
    }

    private var youTubePlaceholder: some View {
        Rectangle()
            .fill(Color.red.opacity(0.8))
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 28))
            )
    }

    private var snsIconPlaceholder: some View {
        Rectangle()
            .fill(snsColor)
            .overlay(
                Image(systemName: "globe")
                    .foregroundColor(.white)
                    .font(.system(size: 28))
            )
    }

    private var snsColor: Color {
        switch video.videoType {
        case "youtube": return .red.opacity(0.8)
        case "twitter": return .blue.opacity(0.8)
        case "instagram": return .purple.opacity(0.8)
        default: return .gray.opacity(0.8)
        }
    }
}

struct VideoRowView: View {
    let video: VideoPlayerList.State.VideoModel

    var body: some View {
        HStack {
            ZStack(alignment: .bottomLeading) {
                if video.isLocalVideo {
                    if let url = video.fileName.documentDirectoryURL() {
                        VideoThumbnail(url: url)
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 120, height: 80)
                            .cornerRadius(8)
                    }
                } else {
                    SNSThumbnailView(video: video)
                }

                // 再生進捗バー（ローカル動画のみ）
                if video.isLocalVideo && video.playbackProgress > 0 {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(height: 3)
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: geometry.size.width * video.playbackProgress, height: 3)
                            }
                        }
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)
                }

                // 続きから再生マーク（ローカル動画のみ）
                if video.isLocalVideo && video.canResumePlayback {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .shadow(radius: 2)
                        .frame(width: 120, height: 80)
                }
            }
            .frame(width: 120, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    if video.isLocalVideo {
                        Text(formatDuration(video.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if video.canResumePlayback {
                            Text("・\(formatDuration(video.lastPlaybackPosition))まで視聴")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text(snsLabel(for: video.videoType))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(formatDate(video.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func snsLabel(for videoType: String?) -> String {
        switch videoType {
        case "youtube": return "YouTube"
        case "twitter": return "Twitter / X"
        case "instagram": return "Instagram"
        default: return "SNS動画"
        }
    }
}


extension String {
    func documentDirectoryURL() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(self)
    }
}


struct VideoPlayerListView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerListView(
            store: Store(
                initialState: VideoPlayerList.State(
                    videos: [
                        .init(
                            id: UUID(),
                            fileName: "sample_video.mp4",
                            title: "サンプルビデオ 1",
                            duration: 185,
                            createdAt: Date(),
                            lastPlaybackPosition: 60,
                            lastPlayedAt: Date(),
                            sourceURL: nil,
                            videoType: "local"
                        ),
                        .init(
                            id: UUID(),
                            fileName: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                            title: "YouTube動画サンプル",
                            duration: 0,
                            createdAt: Date().addingTimeInterval(-86400),
                            lastPlaybackPosition: 0,
                            lastPlayedAt: nil,
                            sourceURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                            videoType: "youtube"
                        )
                    ],
                    isShowingVideoPicker: false, isLoading: false
                ),
                reducer: { VideoPlayerList() }
            )
        )
    }
}

struct VideoRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            VideoRowView(
                video: .init(
                    id: UUID(),
                    fileName: "sample_video.mp4",
                    title: "サンプルビデオ",
                    duration: 185,
                    createdAt: Date(),
                    lastPlaybackPosition: 90,
                    lastPlayedAt: Date(),
                    sourceURL: nil,
                    videoType: "local"
                )
            )
            VideoRowView(
                video: .init(
                    id: UUID(),
                    fileName: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    title: "YouTube動画",
                    duration: 0,
                    createdAt: Date(),
                    lastPlaybackPosition: 0,
                    lastPlayedAt: nil,
                    sourceURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    videoType: "youtube"
                )
            )
        }
    }
}

struct VideoThumbnail_Previews: PreviewProvider {
    static var previews: some View {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            VideoThumbnail(url: documentsURL.appendingPathComponent("sample_video.mp4"))
        }
    }
}
