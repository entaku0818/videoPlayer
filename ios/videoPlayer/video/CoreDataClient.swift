//
//  CoreDataClient.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import CoreData
import Dependencies
struct CoreDataClient {
    var fetchVideos: () async throws -> [SavedVideoEntity]
    var saveVideo: (URL, String, Double) async throws -> Void
    var deleteVideo: (UUID) async throws -> Void
}

// CoreDataクライアントの実装
extension CoreDataClient: DependencyKey {
    static let liveValue = CoreDataClient(
        fetchVideos: {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<SavedVideo>(entityName: "SavedVideo")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedVideo.createdAt, ascending: false)]

            return try await context.perform {
                let savedVideos = try context.fetch(request)

                return savedVideos.compactMap { video -> SavedVideoEntity? in
                    guard let id = video.id,
                          let fileName = video.fileName,
                          let title = video.title,
                          let createdAt = video.createdAt else {
                        return nil
                    }

                    return SavedVideoEntity(
                        id: id,
                        fileName: fileName,
                        title: title,
                        duration: video.duration,
                        createdAt: createdAt
                    )
                }
            }
        },
        saveVideo: { url, title, duration in
            let context = PersistenceController.shared.container.viewContext

            try await context.perform {
                let video = SavedVideo(context: context)
                video.id = UUID()
                video.fileName = url.lastPathComponent
                video.title = title
                video.duration = duration
                video.createdAt = Date()

                try context.save()
            }
        },
        deleteVideo: { id in
            let context = PersistenceController.shared.container.viewContext

            try await context.perform {
                let request = NSFetchRequest<SavedVideo>(entityName: "SavedVideo")
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

                let videos = try context.fetch(request)
                if let video = videos.first {
                    context.delete(video)
                    try context.save()
                }
            }
        }
    )
}

extension CoreDataClient: TestDependencyKey {
    static let previewValue = Self(
        fetchVideos: {
            return [
                SavedVideoEntity(
                    id: UUID(),
                    fileName: "test1.mp4",
                    title: "テスト動画1",
                    duration: 180.0,
                    createdAt: Date()
                ),
                SavedVideoEntity(
                    id: UUID(),
                    fileName: "test2.mp4",
                    title: "テスト動画2",
                    duration: 240.0,
                    createdAt: Date().addingTimeInterval(-86400)
                ),
                SavedVideoEntity(
                    id: UUID(),
                    fileName: "test3.mp4",
                    title: "テスト動画3",
                    duration: 300.0,
                    createdAt: Date().addingTimeInterval(-172800)
                )
            ]
        },
        saveVideo: { _, _, _ in },
        deleteVideo: { _ in }
    )

    static let testValue = previewValue
}

extension DependencyValues {
    var coreDataClient: CoreDataClient {
        get { self[CoreDataClient.self] }
        set { self[CoreDataClient.self] = newValue }
    }
}
