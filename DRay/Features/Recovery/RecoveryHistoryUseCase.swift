import Foundation

struct RecoveryRestoreResult: Sendable {
    let restoredCount: Int
    let failures: [SafeRestoreFailure]
    let history: [RecentlyDeletedItem]
}

struct RecoveryHistoryUseCase {
    private let historyStore: OperationalHistoryStore
    private let safeFileOperations: SafeFileOperationService
    private let maxItems: Int
    private let fileName: String
    private let legacyDefaultsKey: String

    init(
        historyStore: OperationalHistoryStore,
        safeFileOperations: SafeFileOperationService,
        maxItems: Int = 200,
        fileName: String = "recently-deleted.json",
        legacyDefaultsKey: String = "dray.recently.deleted"
    ) {
        self.historyStore = historyStore
        self.safeFileOperations = safeFileOperations
        self.maxItems = max(1, maxItems)
        self.fileName = fileName
        self.legacyDefaultsKey = legacyDefaultsKey
    }

    func loadRecentlyDeleted() -> [RecentlyDeletedItem] {
        historyStore.load(
            [RecentlyDeletedItem].self,
            fileName: fileName,
            legacyDefaultsKey: legacyDefaultsKey
        ) ?? []
    }

    func recordMovedItems(
        _ movedItems: [SafeTrashMove],
        in currentHistory: [RecentlyDeletedItem]
    ) -> [RecentlyDeletedItem] {
        guard !movedItems.isEmpty else { return currentHistory }

        var updated = currentHistory
        for moved in movedItems {
            let item = RecentlyDeletedItem(
                id: UUID(),
                originalPath: moved.originalPath,
                trashedPath: moved.trashedPath,
                deletedAt: Date()
            )
            updated.insert(item, at: 0)
        }
        if updated.count > maxItems {
            updated = Array(updated.prefix(maxItems))
        }
        save(updated)
        return updated
    }

    func removeHistoryItem(
        _ item: RecentlyDeletedItem,
        from currentHistory: [RecentlyDeletedItem]
    ) -> [RecentlyDeletedItem] {
        let updated = currentHistory.filter { $0.id != item.id }
        save(updated)
        return updated
    }

    func restore(
        item: RecentlyDeletedItem,
        from currentHistory: [RecentlyDeletedItem]
    ) -> RecoveryRestoreResult {
        let outcome = safeFileOperations.restore([
            SafeRestoreRequest(originalPath: item.originalPath, trashedPath: item.trashedPath)
        ])
        let restoredCount = outcome.restored.count
        guard restoredCount > 0 else {
            return RecoveryRestoreResult(
                restoredCount: 0,
                failures: outcome.failures,
                history: currentHistory
            )
        }

        let updatedHistory = currentHistory.filter { $0.id != item.id }
        save(updatedHistory)
        return RecoveryRestoreResult(
            restoredCount: restoredCount,
            failures: outcome.failures,
            history: updatedHistory
        )
    }

    func clearHistory() {
        save([])
    }

    private func save(_ history: [RecentlyDeletedItem]) {
        historyStore.save(history, fileName: fileName)
    }
}
