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
        config.selectionLimit = 0
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

        private func createPermanentURL(for fileName: String) -> URL {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return documentsDirectory.appendingPathComponent(fileName)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if results.isEmpty {
                ViewStore(store, observe: { $0 }).send(.toggleVideoPicker)
                return
            }

            var processedCount = 0

            for result in results {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    guard let self = self,
                          let url = url else { return }

                    let uniqueFileName = "\(UUID().uuidString).mov"
                    let permanentURL = createPermanentURL(for: uniqueFileName)

                    do {
                        try FileManager.default.copyItem(at: url, to: permanentURL)

                        Task {
                            let asset = AVAsset(url: permanentURL)
                            let duration = try await asset.load(.duration).seconds
                            let title = result.itemProvider.suggestedName ?? "Untitled Video"

                            await ViewStore(self.store, observe: { $0 }).send(
                                .videoSelected(permanentURL, title, duration)
                            )

                            processedCount += 1

                            if processedCount == results.count {
                                await ViewStore(self.store, observe: { $0 }).send(.toggleVideoPicker)
                            }
                        }
                    } catch {
                        print("Failed to copy video: \(error)")
                        processedCount += 1
                    }
                }
            }
        }
    }
}

