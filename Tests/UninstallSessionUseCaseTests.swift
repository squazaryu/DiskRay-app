import Foundation
import Testing
@testable import DRay

struct UninstallSessionUseCaseTests {
    @Test
    func appendSessionKeepsOnlyRemovedItemsAndCapsHistory() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = "dray.tests.uninstall.session.append.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: defaults,
            directoryURL: tempDir
        )
        let useCase = UninstallSessionUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService(),
            sessionLimit: 2
        )

        var sessions: [UninstallSession] = []
        sessions = useCase.appendSession(
            from: makeReport(appName: "A", removedSuffix: "a"),
            existingSessions: sessions,
            kind: .uninstall
        )
        sessions = useCase.appendSession(
            from: makeReport(appName: "B", removedSuffix: "b"),
            existingSessions: sessions,
            kind: .uninstall
        )
        sessions = useCase.appendSession(
            from: makeReport(appName: "C", removedSuffix: "c"),
            existingSessions: sessions,
            kind: .uninstall
        )

        #expect(sessions.count == 2)
        #expect(sessions[0].appName == "C")
        #expect(sessions[1].appName == "B")
        #expect(sessions[0].rollbackItems.count == 1)

        let loaded = useCase.load(kind: .uninstall)
        #expect(loaded.map(\.appName) == ["C", "B"])
    }

    @Test
    func restoreRemovesRestoredEntriesAndPersistsUpdatedSessions() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = "dray.tests.uninstall.session.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: defaults,
            directoryURL: tempDir
        )
        let useCase = UninstallSessionUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService()
        )

        let originalsRoot = tempDir.appendingPathComponent("originals", isDirectory: true)
        let trashRoot = tempDir.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: originalsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)

        let itemAOriginal = originalsRoot.appendingPathComponent("a.txt")
        let itemATrash = trashRoot.appendingPathComponent("a.txt")
        let itemBOriginal = originalsRoot.appendingPathComponent("b.txt")
        let itemBTrash = trashRoot.appendingPathComponent("b.txt")

        try Data("A".utf8).write(to: itemATrash)
        try Data("B".utf8).write(to: itemBTrash)

        let session = UninstallSession(
            appName: "Demo",
            createdAt: Date(timeIntervalSince1970: 1_726_000_000),
            rollbackItems: [
                UninstallRollbackItem(
                    originalPath: itemAOriginal.path,
                    trashedPath: itemATrash.path,
                    type: .remnant
                ),
                UninstallRollbackItem(
                    originalPath: itemBOriginal.path,
                    trashedPath: itemBTrash.path,
                    type: .remnant
                )
            ]
        )
        useCase.save([session], kind: .repair)

        let result = useCase.restore(
            from: session,
            item: session.rollbackItems[0],
            sessions: [session],
            kind: .repair
        )

        #expect(result.restoredCount == 1)
        #expect(result.failures.isEmpty)
        #expect(result.sessions.count == 1)
        #expect(result.sessions[0].rollbackItems.count == 1)
        #expect(result.sessions[0].rollbackItems[0].originalPath == itemBOriginal.path)
        #expect(FileManager.default.fileExists(atPath: itemAOriginal.path))
        #expect(!FileManager.default.fileExists(atPath: itemATrash.path))

        let persisted = useCase.load(kind: .repair)
        #expect(persisted.count == 1)
        #expect(persisted[0].rollbackItems.count == 1)
        #expect(persisted[0].rollbackItems[0].originalPath == itemBOriginal.path)
    }

    private func makeReport(appName: String, removedSuffix: String) -> UninstallValidationReport {
        UninstallValidationReport(
            appName: appName,
            createdAt: Date(timeIntervalSince1970: 1_726_000_000),
            results: [
                UninstallActionResult(
                    url: URL(fileURLWithPath: "/tmp/\(removedSuffix).txt"),
                    type: .remnant,
                    status: .removed,
                    trashedPath: "/tmp/.Trash/\(removedSuffix).txt",
                    details: nil
                ),
                UninstallActionResult(
                    url: URL(fileURLWithPath: "/tmp/\(removedSuffix)-missing.txt"),
                    type: .remnant,
                    status: .missing,
                    trashedPath: nil,
                    details: "Not found"
                )
            ]
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let url = root.appendingPathComponent("dray-session-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
