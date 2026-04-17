import Foundation

@MainActor
final class RecoveryFeatureController: ObservableObject {
    @Published private(set) var state = RecoveryFeatureState()

    private let recoveryHistoryUseCase: RecoveryHistoryUseCase
    private let recoveryStore: any RecoveryStoring
    private let maxQuickActionSessions: Int

    init(
        recoveryHistoryUseCase: RecoveryHistoryUseCase,
        recoveryStore: any RecoveryStoring,
        maxQuickActionSessions: Int = 80
    ) {
        self.recoveryHistoryUseCase = recoveryHistoryUseCase
        self.recoveryStore = recoveryStore
        self.maxQuickActionSessions = max(1, maxQuickActionSessions)
    }

    func loadHistory() {
        state.recentlyDeleted = recoveryHistoryUseCase.loadRecentlyDeleted()
        state.quickActionRollbackSessions = recoveryStore.loadQuickActionRollbackSessions()
    }

    func recordMovedItems(_ movedItems: [SafeTrashMove]) {
        state.recentlyDeleted = recoveryHistoryUseCase.recordMovedItems(
            movedItems,
            in: state.recentlyDeleted
        )
    }

    func restore(item: RecentlyDeletedItem) -> RecoveryRestoreResult {
        let result = recoveryHistoryUseCase.restore(item: item, from: state.recentlyDeleted)
        if result.restoredCount > 0 {
            state.recentlyDeleted = result.history
        }
        return result
    }

    func removeHistoryItem(_ item: RecentlyDeletedItem) {
        state.recentlyDeleted = recoveryHistoryUseCase.removeHistoryItem(
            item,
            from: state.recentlyDeleted
        )
    }

    func appendRollbackSession(_ session: QuickActionRollbackSession) {
        state.quickActionRollbackSessions.insert(session, at: 0)
        if state.quickActionRollbackSessions.count > maxQuickActionSessions {
            state.quickActionRollbackSessions = Array(state.quickActionRollbackSessions.prefix(maxQuickActionSessions))
        }
        saveQuickActionRollbackSessions()
    }

    func removeRollbackSession(_ session: QuickActionRollbackSession) {
        state.quickActionRollbackSessions.removeAll { $0.id == session.id }
        saveQuickActionRollbackSessions()
    }

    func clearRecoveryHistory() {
        state.recentlyDeleted = []
        state.quickActionRollbackSessions = []
        recoveryHistoryUseCase.clearHistory()
        saveQuickActionRollbackSessions()
    }

    func markLatestRollbackSessionResolved(summary: String) {
        guard let index = state.quickActionRollbackSessions.firstIndex(where: { $0.canRollback }) else { return }
        state.quickActionRollbackSessions[index].restoredAt = Date()
        state.quickActionRollbackSessions[index].rollbackSummary = summary
        saveQuickActionRollbackSessions()
    }

    @discardableResult
    func restoreSession(
        _ session: QuickActionRollbackSession,
        restorePriorities: (_ limit: Int) -> LoadReliefResult
    ) -> String? {
        guard session.canRollback else { return nil }

        switch session.rollbackKind {
        case .none:
            return nil
        case .restorePriorities:
            let limit = max(5, session.adjustedTargets.count)
            let result = restorePriorities(limit)
            let summary = "Restored \(result.adjusted.count), failed \(result.failed.count), skipped \(result.skipped.count)"
            updateRollbackSession(id: session.id, restoredAt: Date(), summary: summary)
            return summary
        }
    }

    private func saveQuickActionRollbackSessions() {
        recoveryStore.saveQuickActionRollbackSessions(state.quickActionRollbackSessions)
    }

    private func updateRollbackSession(id: UUID, restoredAt: Date, summary: String) {
        guard let index = state.quickActionRollbackSessions.firstIndex(where: { $0.id == id }) else { return }
        state.quickActionRollbackSessions[index].restoredAt = restoredAt
        state.quickActionRollbackSessions[index].rollbackSummary = summary
        saveQuickActionRollbackSessions()
    }
}
