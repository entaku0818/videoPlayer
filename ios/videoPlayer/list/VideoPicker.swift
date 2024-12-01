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
       config.selectionLimit = 1

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
           ViewStore(store, observe: { $0 }).send(.toggleVideoPicker)

           guard let result = results.first else { return }

           result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
               guard let url = url else { return }

               // ドキュメントディレクトリのURLを取得
               let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
               let uniqueFileName = "\(UUID().uuidString).mov"
               let destinationURL = documentsDirectory.appendingPathComponent(uniqueFileName)

               do {
                   // 一時ファイルを永続的な保存場所にコピー
                   try FileManager.default.copyItem(at: url, to: destinationURL)

                   Task {
                       let asset = AVAsset(url: destinationURL)
                       let duration = try await asset.load(.duration).seconds
                       let title = result.itemProvider.suggestedName ?? "Untitled Video"

                       await ViewStore(self.store, observe: { $0 }).send(
                           .videoSelected(destinationURL, title, duration)
                       )
                   }
               } catch {
                   print("Failed to copy video: \(error)")
               }
           }
       }
   }
}
