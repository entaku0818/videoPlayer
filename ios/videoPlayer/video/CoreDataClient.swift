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
                          let url = video.url,
                          let title = video.title,
                          let createdAt = video.createdAt else {
                        return nil
                    }

                    return SavedVideoEntity(
                        id: id,
                        url: url,
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
                video.url = url
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

extension CoreDataClient:TestDependencyKey {
    static let previewValue = Self(
        fetchVideos: { [] },
        saveVideo: { _, _, _ in },
        deleteVideo: { _ in }
    )

    static let testValue = Self(
        fetchVideos: { [] },
        saveVideo: { _, _, _ in },
        deleteVideo: { _ in }
    )
}

extension DependencyValues {
    var coreDataClient: CoreDataClient {
        get { self[CoreDataClient.self] }
        set { self[CoreDataClient.self] = newValue }
    }
}
