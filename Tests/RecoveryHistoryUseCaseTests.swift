import Foundation
import Testing
@testable import DRay

struct RecoveryHistoryUseCaseTests {
    @Test
    func loadMigratesLegacyUserDefaultsHistory() throws {
        let tempDir = try makeTemporaryDirectory()
        let suiteName = "RecoveryHistoryUseCaseTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let legacyItem = RecentlyDeletedItem(
            id: UUID(),
            originalPath: "/tmp/original.txt",
            trashedPath: "/tmp/.Trash/original.txt",
            deletedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let legacyKey = "dray.recently.deleted"
        let data = try JSONEncoder().encode([legacyItem])
        userDefaults.set(data, forKey: legacyKey)

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: userDefaults,
            directoryURL: tempDir
        )
        let useCase = RecoveryHistoryUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService()
        )

        let loaded = useCase.loadRecentlyDeleted()

        #expect(loaded.count == 1)
        #expect(loaded.first?.originalPath == legacyItem.originalPath)
        #expect(userDefaults.data(forKey: legacyKey) == nil)
    }

    @Test
    func recordMovedItemsCapsHistoryAndPersists() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = OperationalHistoryStore(directoryURL: tempDir)
        let useCase = RecoveryHistoryUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService(),
            maxItems: 2
        )

        let updated = useCase.recordMovedItems(
            [
                SafeTrashMove(originalPath: "/tmp/a", trashedPath: "/tmp/.Trash/a"),
                SafeTrashMove(originalPath: "/tmp/b", trashedPath: "/tmp/.Trash/b"),
                SafeTrashMove(originalPath: "/tmp/c", trashedPath: "/tmp/.Trash/c")
            ],
            in: []
        )

        #expect(updated.count == 2)
        #expect(updated.map(\.originalPath) == ["/tmp/c", "/tmp/b"])

        let persisted = useCase.loadRecentlyDeleted()
        #expect(persisted.map(\.originalPath) == ["/tmp/c", "/tmp/b"])
    }

    @Test
    func restoreRemovesItemFromHistoryWhenFileRestored() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let trashDir = tempDir.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let trashedFile = trashDir.appendingPathComponent("file.txt")
        try Data("payload".utf8).write(to: trashedFile)

        let originalFile = tempDir.appendingPathComponent("Restored/file.txt")
        let historyItem = RecentlyDeletedItem(
            id: UUID(),
            originalPath: originalFile.path,
            trashedPath: trashedFile.path,
            deletedAt: Date()
        )

        let store = OperationalHistoryStore(directoryURL: tempDir)
        let useCase = RecoveryHistoryUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService()
        )
        _ = useCase.recordMovedItems(
            [SafeTrashMove(originalPath: historyItem.originalPath, trashedPath: historyItem.trashedPath)],
            in: []
        )

        let result = useCase.restore(item: historyItem, from: [historyItem])

        #expect(result.restoredCount == 1)
        #expect(result.failures.isEmpty)
        #expect(result.history.isEmpty)
        #expect(FileManager.default.fileExists(atPath: originalFile.path))
        #expect(!FileManager.default.fileExists(atPath: trashedFile.path))
        #expect(useCase.loadRecentlyDeleted().isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-recovery-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
