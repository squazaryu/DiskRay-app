import Foundation
import Testing
@testable import DRay

@Suite("SQLiteIndexStoreTests")
struct SQLiteIndexStoreTests {
    @Test
    func storesAndReplacesRootOnlySnapshot() throws {
        let fixture = try StoreFixture()
        let store = try #require(SQLiteIndexStore(databaseURL: fixture.databaseURL))

        #expect(store.saveSnapshot(root: directory("/Users/test", size: 0)))
        let emptyRoot = try #require(store.loadSnapshot(rootPath: "/Users/test"))
        #expect(emptyRoot.children.isEmpty)
        #expect(emptyRoot.sizeInBytes == 0)

        #expect(store.saveSnapshot(root: directory(
            "/Users/test",
            size: 18,
            children: [file("/Users/test/replacement.txt", size: 18)]
        )))
        let replacement = try #require(store.loadSnapshot(rootPath: "/Users/test"))
        #expect(replacement.sizeInBytes == 18)
        #expect(replacement.children.map(\.url.path) == ["/Users/test/replacement.txt"])
    }

    @Test
    func storesSnapshotsForMultipleRootsIndependently() throws {
        let fixture = try StoreFixture()
        let store = try #require(SQLiteIndexStore(databaseURL: fixture.databaseURL))
        let home = directory(
            "/Users/test",
            size: 12,
            children: [file("/Users/test/report.txt", size: 12)]
        )
        let applications = directory(
            "/Applications",
            size: 40,
            children: [file("/Applications/Test.app", size: 40)]
        )

        #expect(store.saveSnapshot(root: home))
        #expect(store.saveSnapshot(root: applications))

        let loadedHome = try #require(store.loadSnapshot(rootPath: "/Users/test"))
        let loadedApplications = try #require(store.loadSnapshot(rootPath: "/Applications"))
        #expect(loadedHome.children.map(\.url.path) == ["/Users/test/report.txt"])
        #expect(loadedApplications.children.map(\.url.path) == ["/Applications/Test.app"])
    }

    @Test
    func failedSaveRollsBackToPreviousSnapshot() throws {
        let fixture = try StoreFixture()
        let store = try #require(SQLiteIndexStore(databaseURL: fixture.databaseURL))
        let valid = directory(
            "/Users/test",
            size: 12,
            children: [file("/Users/test/original.txt", size: 12)]
        )
        let duplicatePath = "/Users/test/duplicate.txt"
        let invalid = directory(
            "/Users/test",
            size: 20,
            children: [
                file(duplicatePath, size: 10),
                file(duplicatePath, size: 10)
            ]
        )

        #expect(store.saveSnapshot(root: valid))
        #expect(!store.saveSnapshot(root: invalid))
        #expect(store.lastErrorMessage?.contains("UNIQUE constraint failed") == true)

        let loaded = try #require(store.loadSnapshot(rootPath: "/Users/test"))
        #expect(loaded.children.map(\.url.path) == ["/Users/test/original.txt"])
    }

    @Test
    func failedCommitRollsBackToPreviousSnapshot() throws {
        let fixture = try StoreFixture()
        let baselineStore = try #require(SQLiteIndexStore(databaseURL: fixture.databaseURL))
        #expect(baselineStore.saveSnapshot(root: directory(
            "/Users/test",
            size: 12,
            children: [file("/Users/test/original.txt", size: 12)]
        )))

        let failingStore = try #require(SQLiteIndexStore(
            databaseURL: fixture.databaseURL,
            injectedFailurePoints: [.commit]
        ))
        #expect(!failingStore.saveSnapshot(root: directory(
            "/Users/test",
            size: 20,
            children: [file("/Users/test/replacement.txt", size: 20)]
        )))
        #expect(failingStore.lastErrorMessage == "commit snapshot transaction: injected failure")

        let loaded = try #require(failingStore.loadSnapshot(rootPath: "/Users/test"))
        #expect(loaded.children.map(\.url.path) == ["/Users/test/original.txt"])
    }

    @Test
    func clearRemovesAllRootSnapshots() throws {
        let fixture = try StoreFixture()
        let store = try #require(SQLiteIndexStore(databaseURL: fixture.databaseURL))

        #expect(store.saveSnapshot(root: directory("/Users/test", size: 0)))
        #expect(store.saveSnapshot(root: directory("/Applications", size: 0)))
        #expect(store.clearSnapshotCache())
        #expect(store.loadSnapshot(rootPath: "/Users/test") == nil)
        #expect(store.loadSnapshot(rootPath: "/Applications") == nil)
    }

    @Test
    func corruptCacheIsRebuiltOnce() throws {
        let fixture = try StoreFixture()
        try Data("not a sqlite database".utf8).write(to: fixture.databaseURL)

        let store = try #require(SQLiteIndexStore(databaseURL: fixture.databaseURL))
        let root = directory("/Users/test", size: 0)
        #expect(store.saveSnapshot(root: root))
        #expect(store.loadSnapshot(rootPath: "/Users/test")?.url.path == "/Users/test")
    }

    private func directory(_ path: String, size: Int64, children: [FileNode] = []) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: path),
            name: URL(fileURLWithPath: path).lastPathComponent,
            isDirectory: true,
            sizeInBytes: size,
            children: children
        )
    }

    private func file(_ path: String, size: Int64) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: path),
            name: URL(fileURLWithPath: path).lastPathComponent,
            isDirectory: false,
            sizeInBytes: size,
            children: []
        )
    }
}

private final class StoreFixture {
    let directoryURL: URL
    let databaseURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DRaySQLiteIndexStoreTests-\(UUID().uuidString)", isDirectory: true)
        databaseURL = directoryURL.appendingPathComponent("index.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
