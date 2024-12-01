//
//  VideoPicker.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/02.
//

import SwiftUI
import PhotosUI
import AVFoundation
import ComposableArchitecture

struct VideoPicker: UIViewControllerRepresentable {
    let store: StoreOf<VideoPlayerList>

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 0  // 0は制限なしを意味します

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let store: StoreOf<VideoPlayerList>

        init(store: StoreOf<VideoPlayerList>) {
            self.store = store
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // 選択をキャンセルした場合はすぐにピッカーを閉じる
            if results.isEmpty {
                ViewStore(store, observe: { $0 }).send(.toggleVideoPicker)
                return
            }

            // 処理済みの動画をカウントする
            var processedCount = 0

            // 選択された各動画を処理
            for result in results {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    guard let self = self,
                          let url = url else { return }

                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let uniqueFileName = "\(UUID().uuidString).mov"
                    let destinationURL = documentsDirectory.appendingPathComponent(uniqueFileName)

                    do {
                        try FileManager.default.copyItem(at: url, to: destinationURL)

                        Task {
                            let asset = AVAsset(url: destinationURL)
                            let duration = try await asset.load(.duration).seconds
                            let title = result.itemProvider.suggestedName ?? "Untitled Video"

                            await ViewStore(self.store, observe: { $0 }).send(
                                .videoSelected(destinationURL, title, duration)
                            )

                            // カウントをインクリメント
                            processedCount += 1

                            // すべての動画の処理が完了した場合のみピッカーを閉じる
                            if processedCount == results.count {
                                await ViewStore(self.store, observe: { $0 }).send(.toggleVideoPicker)
                            }
                        }
                    } catch {
                        print("Failed to copy video: \(error)")
                        // エラーの場合もカウントする
                        processedCount += 1
                    }
                }
            }
        }
    }
}
