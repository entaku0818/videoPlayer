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
                                    VideoPlayerView(
                                        store: Store(
                                            initialState: VideoPlayer.State(
                                                id: video.id, fileName: video.fileName
                                            ),
                                            reducer: { VideoPlayer() }
                                        )
                                    )
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
                    isPresented: .constant(viewStore.isShowingVideoPicker)
                ) {
                    VideoPicker(store: store)
                }
                .sheet(
                    isPresented: .constant(viewStore.isShowingURLInput)
                ) {
                    URLInputSheet(store: store)
                }
                .alert(
                    "エラー",
                    isPresented: .constant(viewStore.downloadError != nil),
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

                    Text("MP4, WebM, MOV などの直接リンクを入力してください")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.top, 30)
                .navigationTitle("URLからダウンロード")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            viewStore.send(.closeURLInput)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("ダウンロード") {
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

struct VideoRowView: View {
    let video: VideoPlayerList.State.VideoModel

    var body: some View {
        HStack {
            if let url = video.fileName.documentDirectoryURL() {
                VideoThumbnail(url: url)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 120, height: 80)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)

                Text(formatDuration(video.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)

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
                            createdAt: Date()
                        ),
                        .init(
                            id: UUID(),
                            fileName: "another_video.mp4",
                            title: "サンプルビデオ 2",
                            duration: 260,
                            createdAt: Date().addingTimeInterval(-86400)
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
                    createdAt: Date()
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
