//
//  PersistenceControllerTests.swift
//  videoPlayerTests
//

import XCTest
import CoreData
@testable import videoPlayer

final class PersistenceControllerTests: XCTestCase {

    // MARK: - ストアURL検証

    /// CoreData ストアがファイルURL（SQLite）を持つことを検証する。
    /// URL なしの NSPersistentStoreDescription を誤ってセットするとメモリストアになり、
    /// アプリ再起動後にデータが消えてしまう。このテストでその問題を検出する。
    func testPersistentStoreHasFileURL() throws {
        let controller = PersistenceController()
        let description = try XCTUnwrap(
            controller.container.persistentStoreDescriptions.first,
            "persistentStoreDescriptions が空です"
        )
        let storeURL = try XCTUnwrap(
            description.url,
            "ストアURLがnil - URL なしの NSPersistentStoreDescription で上書きされている可能性があります"
        )
        XCTAssertTrue(storeURL.isFileURL, "ストアはファイルURLである必要があります（インメモリストアではなく）")
        XCTAssertTrue(
            storeURL.pathExtension == "sqlite" || storeURL.lastPathComponent.contains("VideoModel"),
            "ストアは VideoModel.sqlite を指している必要があります: \(storeURL)"
        )
    }

    // MARK: - 再起動シミュレーション

    /// 保存したデータが新しい PersistenceController インスタンスからも取得できることを検証する。
    /// これはアプリ再起動後もデータが残るかのシミュレーション。
    func testDataPersistsAcrossControllerReinit() async throws {
        // テスト用の一時SQLiteファイルを使う
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let testID = UUID()

        // --- 1回目の起動：データを保存 ---
        let controller1 = makePersistenceController(storeURL: tempURL)
        let ctx1 = controller1.container.viewContext
        try await ctx1.perform {
            let video = SavedVideo(context: ctx1)
            video.id = testID
            video.fileName = "test_persist.mp4"
            video.title = "永続化テスト"
            video.duration = 120
            video.createdAt = Date()
            try ctx1.save()
        }

        // --- 2回目の起動：同じファイルから読み込み ---
        let controller2 = makePersistenceController(storeURL: tempURL)
        let ctx2 = controller2.container.viewContext
        let fetched = try await ctx2.perform {
            let request = NSFetchRequest<SavedVideo>(entityName: "SavedVideo")
            request.predicate = NSPredicate(format: "id == %@", testID as CVarArg)
            return try ctx2.fetch(request)
        }

        XCTAssertFalse(fetched.isEmpty, "再起動後にデータが消えています")
        XCTAssertEqual(fetched.first?.title, "永続化テスト")
    }

    // MARK: - Helper

    private func makePersistenceController(storeURL: URL) -> PersistenceController {
        let container = NSPersistentContainer(name: "VideoModel")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { XCTFail("CoreData load failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return PersistenceController(container: container)
    }
}
