//
//  IPTVViews.swift
//  videoPlayer
//
//  IPTV タブ: ユーザー自身が持つ M3U プレイリストを登録・再生する。
//  本アプリはチャンネル・プレイリスト・配信URLを提供しない（審査ガイドライン 5.2.3）。
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers
import ComposableArchitecture

enum IPTVCopy {
    static let disclaimer = "本アプリはチャンネル・番組・プレイリストを提供しません。ご自身で作成した、または正規に契約・入手したM3U/M3U8プレイリストのみを追加してください。"
}

// MARK: - プレイリスト一覧

struct IPTVPlaylistListView: View {
    @Bindable var store: StoreOf<IPTVPlaylistList>

    var body: some View {
        NavigationStack {
            Group {
                if store.playlists.isEmpty {
                    emptyState
                } else {
                    playlistList
                }
            }
            .navigationTitle("IPTV")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SettingsButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("プレイリストを追加")
                }
            }
            .navigationDestination(
                item: $store.scope(state: \.channelList, action: \.channelList)
            ) { channelStore in
                IPTVChannelListView(store: channelStore)
            }
            .sheet(isPresented: Binding(
                get: { store.isShowingAddSheet },
                set: { if !$0 { store.send(.addSheetDismissed) } }
            )) {
                AddPlaylistSheet(store: store)
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { store.errorMessage != nil && !store.isShowingAddSheet },
                    set: { if !$0 { store.send(.errorDismissed) } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("プレイリストがありません")
                .font(.headline)
            Text("お手持ちのM3U/M3U8プレイリストのURLまたはファイルを追加すると、チャンネル一覧から再生できます。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                store.send(.addButtonTapped)
            } label: {
                Label("プレイリストを追加", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Text(IPTVCopy.disclaimer)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(32)
    }

    private var playlistList: some View {
        List {
            Section {
                ForEach(store.playlists) { playlist in
                    Button {
                        store.send(.playlistTapped(playlist.id))
                    } label: {
                        PlaylistRow(
                            playlist: playlist,
                            isRefreshing: store.refreshingPlaylistID == playlist.id
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        if playlist.sourceURL != nil {
                            Button {
                                store.send(.refreshPlaylist(playlist.id))
                            } label: {
                                Label("更新", systemImage: "arrow.clockwise")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .onDelete { store.send(.deletePlaylists($0)) }
            } footer: {
                Text(IPTVCopy.disclaimer)
            }
        }
    }
}

private struct PlaylistRow: View {
    let playlist: IPTVPlaylist
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: playlist.sourceURL == nil ? "doc.text" : "link")
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(playlist.channels.count)チャンネル・\(playlist.updatedAt.formatted(date: .abbreviated, time: .shortened))更新")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isRefreshing {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

// MARK: - プレイリスト追加

struct AddPlaylistSheet: View {
    @Bindable var store: StoreOf<IPTVPlaylistList>

    private static let allowedTypes: [UTType] = [
        .m3uPlaylist,
        UTType(filenameExtension: "m3u8") ?? .m3uPlaylist,
        .plainText,
        .data
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前（任意）", text: $store.nameInput)
                }

                Section {
                    TextField("https://...", text: $store.urlInput)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("URLから追加") {
                        store.send(.addFromURLTapped)
                    }
                    .disabled(store.urlInput.trimmingCharacters(in: .whitespaces).isEmpty || store.isImporting)
                } header: {
                    Text("プレイリストのURL")
                } footer: {
                    Text("ご自身のM3U/M3U8プレイリストのURLを入力してください。")
                }

                Section {
                    Button {
                        store.send(.importFileTapped)
                    } label: {
                        Label("ファイルから読み込む", systemImage: "folder")
                    }
                    .disabled(store.isImporting)
                } footer: {
                    Text(IPTVCopy.disclaimer)
                }

                if let error = store.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("プレイリストを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.send(.addSheetDismissed)
                    }
                }
            }
            .overlay {
                if store.isImporting {
                    ProgressView("読み込み中...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .fileImporter(
                isPresented: $store.isShowingFileImporter,
                allowedContentTypes: Self.allowedTypes
            ) { result in
                store.send(.fileSelected(result))
            }
            .onDisappear {
                if store.errorMessage != nil { store.send(.errorDismissed) }
            }
        }
    }
}

// MARK: - チャンネル一覧

struct IPTVChannelListView: View {
    @Bindable var store: StoreOf<IPTVChannelList>

    var body: some View {
        List {
            ForEach(store.sections) { section in
                Section(section.title) {
                    ForEach(section.channels) { channel in
                        Button {
                            store.send(.channelTapped(channel))
                        } label: {
                            ChannelRow(channel: channel)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            if store.sections.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            }
        }
        .searchable(text: $store.searchText, prompt: "チャンネルを検索")
        .navigationTitle(store.playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        store.send(.groupSelected(nil))
                    } label: {
                        if store.selectedGroup == nil {
                            Label("すべて", systemImage: "checkmark")
                        } else {
                            Text("すべて")
                        }
                    }
                    ForEach(store.groups, id: \.self) { group in
                        Button {
                            store.send(.groupSelected(group))
                        } label: {
                            if store.selectedGroup == group {
                                Label(group, systemImage: "checkmark")
                            } else {
                                Text(group)
                            }
                        }
                    }
                } label: {
                    Image(systemName: store.selectedGroup == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("グループで絞り込み")
            }
        }
        .fullScreenCover(item: Binding(
            get: { store.playingChannel },
            set: { if $0 == nil { store.send(.playerDismissed) } }
        )) { channel in
            IPTVPlayerView(channel: channel) {
                store.send(.playerDismissed)
            }
        }
    }
}

private struct ChannelRow: View {
    let channel: IPTVChannel

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.logoURL.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "tv")
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, height: 32)
            Text(channel.name)
                .lineLimit(1)
            Spacer()
            Image(systemName: "play.circle")
                .foregroundColor(.accentColor)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - ライブ再生

final class IPTVPlayerModel: ObservableObject {
    let player: AVPlayer?
    @Published var errorMessage: String?
    private var statusObservation: NSKeyValueObservation?

    init(urlString: String) {
        guard let url = URL(string: urlString) else {
            player = nil
            errorMessage = "無効なURLです"
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "不明なエラー"
            DispatchQueue.main.async {
                self?.errorMessage = "再生できませんでした: \(message)"
            }
        }
    }

    deinit {
        statusObservation?.invalidate()
    }
}

struct IPTVPlayerView: View {
    let channel: IPTVChannel
    let onDismiss: () -> Void
    @StateObject private var model: IPTVPlayerModel

    init(channel: IPTVChannel, onDismiss: @escaping () -> Void) {
        self.channel = channel
        self.onDismiss = onDismiss
        _model = StateObject(wrappedValue: IPTVPlayerModel(urlString: channel.url))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let error = model.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let player = model.player {
                IPTVPlayerController(player: player, title: channel.name)
                    .ignoresSafeArea()
            }

            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
                .accessibilityLabel("閉じる")
                Text(channel.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(radius: 3)
                    .lineLimit(1)
            }
            .padding()
        }
        .onAppear { model.player?.play() }
        .onDisappear { model.player?.pause() }
    }
}

private struct IPTVPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    let title: String

    final class Coordinator {
        var backgroundPlayback: BackgroundPlaybackCoordinator?
        let pictureInPicture = PictureInPictureTracker()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        // 標準コントロールの PiP ボタンに加え、再生中にホームへ戻ったら自動で PiP（iOS 設定の「自動的に開始」に従う）
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = context.coordinator.pictureInPicture
        let backgroundPlayback = BackgroundPlaybackCoordinator(
            controller: controller,
            player: player,
            title: title,
            onPlay: { [weak player] in player?.play() },
            onPause: { [weak player] in player?.pause() }
        )
        let pictureInPicture = context.coordinator.pictureInPicture
        backgroundPlayback.isPictureInPictureActive = { [weak pictureInPicture] in pictureInPicture?.isActive ?? false }
        backgroundPlayback.activate()
        context.coordinator.backgroundPlayback = backgroundPlayback
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // バックグラウンドで切り離し中は再接続しない（復帰時に BackgroundPlaybackCoordinator が戻す）
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.backgroundPlayback?.invalidate()
        coordinator.backgroundPlayback = nil
    }
}
