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
import os.log

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
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "VideoPicker")

            if results.isEmpty {
                logger.debug("No videos selected, closing picker")
                ViewStore(store, observe: { $0 }).send(.closeVideoPicker)
                return
            }

            logger.info("Processing \(results.count) selected videos")
            var processedCount = 0

            for result in results {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    guard let self = self,
                          let url = url else {
                        logger.error("Failed to load video: \(String(describing: error))")
                        return
                    }

                    let uniqueFileName = "\(UUID().uuidString).mov"
                    let permanentURL = createPermanentURL(for: uniqueFileName)
                    logger.debug("Copying video to permanent storage: \(uniqueFileName)")

                    do {
                        try FileManager.default.copyItem(at: url, to: permanentURL)
                        logger.info("Successfully copied video to: \(permanentURL.path)")

                        Task {
                            do {
                                let asset = AVAsset(url: permanentURL)
                                let duration = try await asset.load(.duration).seconds
                                let title = result.itemProvider.suggestedName ?? "Untitled Video"

                                logger.debug("Video details - Title: \(title), Duration: \(duration) seconds")

                                await ViewStore(self.store, observe: { $0 }).send(
                                    .videoSelected(permanentURL, title, duration)
                                )

                                processedCount += 1
                                logger.info("Processed \(processedCount) of \(results.count) videos")

                                if processedCount == results.count {
                                    logger.info("All videos processed, reopening picker")

                                    ViewStore(self.store, observe: { $0 }).send(.closeVideoPicker)

                                }
                            } catch {
                                logger.error("Failed to load video asset: \(error.localizedDescription)")
                            }
                        }
                    } catch {
                        logger.error("Failed to copy video: \(error.localizedDescription)")
                        processedCount += 1
                    }
                }
            }
        }    }
}

