//
//  File.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/02.
//

import SwiftUI
import ComposableArchitecture

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

struct VideoRowView: View {
    let video: VideoPlayerList.State.VideoModel

    var body: some View {
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
