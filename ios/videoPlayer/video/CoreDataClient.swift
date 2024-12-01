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
extension CoreDataClient {
    static let live = Self(
        fetchVideos: {
            try await withCheckedThrowingContinuation { continuation in
                let context = PersistenceController.shared.container.viewContext
                let request = NSFetchRequest<SavedVideo>(entityName: "SavedVideo")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedVideo.createdAt, ascending: false)]

                context.perform {
                    do {
                        let savedVideos = try context.fetch(request)
                        let models = savedVideos.compactMap { video -> SavedVideoEntity? in
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
                        continuation.resume(returning: models)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        },

        saveVideo: { url, title, duration in
            try await withCheckedThrowingContinuation { continuation in
                let context = PersistenceController.shared.container.viewContext

                context.perform {
                    let video = SavedVideo(context: context)
                    video.id = UUID()
                    video.url = url
                    video.title = title
                    video.duration = duration
                    video.createdAt = Date()

                    do {
                        try context.save()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        },

        deleteVideo: { id in
            try await withCheckedThrowingContinuation { continuation in
                let context = PersistenceController.shared.container.viewContext
                let request = NSFetchRequest<SavedVideo>(entityName: "SavedVideo")
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

                context.perform {
                    do {
                        let videos = try context.fetch(request)
                        if let video = videos.first {
                            context.delete(video)
                            try context.save()
                        }
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
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
