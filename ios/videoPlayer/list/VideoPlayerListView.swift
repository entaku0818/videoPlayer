//
//  VideoPlayerListView.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/02.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

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
                                                id: UUID(), url: video.url
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
                    Button {
                        viewStore.send(.toggleVideoPicker)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.isShowingVideoPicker,
                        send: .toggleVideoPicker
                    )
                ) {
                    VideoPicker(store: store)
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
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
            VideoThumbnail(url: video.url)

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
