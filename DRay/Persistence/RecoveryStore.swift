import Foundation

protocol RecoveryStoring {
    func loadQuickActionRollbackSessions() -> [QuickActionRollbackSession]
    func saveQuickActionRollbackSessions(_ sessions: [QuickActionRollbackSession])
}

struct RecoveryStore: RecoveryStoring {
    private let historyStore: OperationalHistoryStore
    private let quickActionRollbackSessionsFileName: String

    init(
        historyStore: OperationalHistoryStore,
        quickActionRollbackSessionsFileName: String = "quick-action-rollback-sessions.json"
    ) {
        self.historyStore = historyStore
        self.quickActionRollbackSessionsFileName = quickActionRollbackSessionsFileName
    }

    func loadQuickActionRollbackSessions() -> [QuickActionRollbackSession] {
        historyStore.load(
            [QuickActionRollbackSession].self,
            fileName: quickActionRollbackSessionsFileName
        ) ?? []
    }

    func saveQuickActionRollbackSessions(_ sessions: [QuickActionRollbackSession]) {
        historyStore.save(sessions, fileName: quickActionRollbackSessionsFileName)
    }
}
