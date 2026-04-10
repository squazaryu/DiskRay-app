import Foundation
import Testing
@testable import DRay

@MainActor
struct RecoveryFeatureControllerTests {
    @Test
    func restoreSessionMarksRollbackAsApplied() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let controller = makeController(tempDir: tempDir)
        let session = QuickActionRollbackSession(
            module: .performance,
            actionTitle: "Reduce CPU",
            rollbackKind: .restorePriorities,
            adjustedTargets: ["WindowServer", "Finder"]
        )
        controller.appendRollbackSession(session)

        let summary = controller.restoreSession(session) { limit in
            #expect(limit >= 5)
            return LoadReliefResult(adjusted: ["WindowServer"], skipped: [], failed: [])
        }

        #expect(summary == "Restored 1, failed 0, skipped 0")
        let stored = try #require(controller.state.quickActionRollbackSessions.first)
        #expect(stored.canRollback == false)
        #expect(stored.rollbackSummary == "Restored 1, failed 0, skipped 0")
    }

    @Test
    func loadHistoryRestoresRecentlyDeletedAndRollbackSessions() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let controller = makeController(tempDir: tempDir)
        controller.recordMovedItems([
            SafeTrashMove(
                originalPath: "/Users/test/file.txt",
                trashedPath: "/Users/test/.Trash/file.txt"
            )
        ])
        controller.appendRollbackSession(
            QuickActionRollbackSession(
                module: .performance,
                actionTitle: "Reduce Memory",
                rollbackKind: .restorePriorities,
                adjustedTargets: ["AppA"]
            )
        )

        let secondController = makeController(tempDir: tempDir)
        secondController.loadHistory()

        #expect(secondController.state.recentlyDeleted.count == 1)
        #expect(secondController.state.quickActionRollbackSessions.count == 1)
    }

    private func makeController(tempDir: URL) -> RecoveryFeatureController {
        let store = OperationalHistoryStore(directoryURL: tempDir)
        return RecoveryFeatureController(
            recoveryHistoryUseCase: RecoveryHistoryUseCase(
                historyStore: store,
                safeFileOperations: SafeFileOperationService()
            ),
            recoveryStore: RecoveryStore(historyStore: store)
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-recovery-controller-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
