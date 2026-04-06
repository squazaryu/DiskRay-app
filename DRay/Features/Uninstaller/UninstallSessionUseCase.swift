import Foundation

enum UninstallSessionKind: Sendable {
    case uninstall
    case repair

    var legacyDefaultsKey: String {
        switch self {
        case .uninstall: return "dray.uninstall.sessions"
        case .repair: return "dray.repair.sessions"
        }
    }

    var fileName: String {
        switch self {
        case .uninstall: return "uninstall-sessions.json"
        case .repair: return "repair-sessions.json"
        }
    }
}

struct UninstallSessionRestoreResult: Sendable {
    let restoredCount: Int
    let failures: [SafeRestoreFailure]
    let sessions: [UninstallSession]
}

struct UninstallSessionUseCase {
    private let historyStore: OperationalHistoryStore
    private let safeFileOperations: SafeFileOperationService
    private let sessionLimit: Int

    init(
        historyStore: OperationalHistoryStore,
        safeFileOperations: SafeFileOperationService,
        sessionLimit: Int = 50
    ) {
        self.historyStore = historyStore
        self.safeFileOperations = safeFileOperations
        self.sessionLimit = max(1, sessionLimit)
    }

    func load(kind: UninstallSessionKind) -> [UninstallSession] {
        historyStore.load(
            [UninstallSession].self,
            fileName: kind.fileName,
            legacyDefaultsKey: kind.legacyDefaultsKey
        ) ?? []
    }

    func save(_ sessions: [UninstallSession], kind: UninstallSessionKind) {
        historyStore.save(sessions, fileName: kind.fileName)
    }

    func appendSession(
        from report: UninstallValidationReport,
        existingSessions: [UninstallSession],
        kind: UninstallSessionKind
    ) -> [UninstallSession] {
        let rollbackItems = report.results.compactMap { result -> UninstallRollbackItem? in
            guard result.status == .removed, let trashedPath = result.trashedPath else { return nil }
            return UninstallRollbackItem(
                originalPath: result.url.path,
                trashedPath: trashedPath,
                type: result.type
            )
        }
        guard !rollbackItems.isEmpty else { return existingSessions }

        let session = UninstallSession(
            appName: report.appName,
            createdAt: report.createdAt,
            rollbackItems: rollbackItems
        )

        var updated = existingSessions
        updated.insert(session, at: 0)
        if updated.count > sessionLimit {
            updated = Array(updated.prefix(sessionLimit))
        }
        save(updated, kind: kind)
        return updated
    }

    func restore(
        from session: UninstallSession,
        item: UninstallRollbackItem? = nil,
        sessions: [UninstallSession],
        kind: UninstallSessionKind
    ) -> UninstallSessionRestoreResult {
        let targets = item.map { [$0] } ?? session.rollbackItems
        let restoreRequests = targets.map {
            SafeRestoreRequest(originalPath: $0.originalPath, trashedPath: $0.trashedPath)
        }
        let outcome = safeFileOperations.restore(restoreRequests)
        let restoredCount = outcome.restored.count

        guard restoredCount > 0 else {
            return UninstallSessionRestoreResult(
                restoredCount: 0,
                failures: outcome.failures,
                sessions: sessions
            )
        }

        let restoredTrashedPaths = Set(outcome.restored.map(\.trashedPath))
        let updatedSessions: [UninstallSession] = sessions.compactMap { current -> UninstallSession? in
            let remainingItems = current.rollbackItems.filter { !restoredTrashedPaths.contains($0.trashedPath) }
            guard !remainingItems.isEmpty else { return nil }
            return UninstallSession(
                appName: current.appName,
                createdAt: current.createdAt,
                rollbackItems: remainingItems
            )
        }
        save(updatedSessions, kind: kind)

        return UninstallSessionRestoreResult(
            restoredCount: restoredCount,
            failures: outcome.failures,
            sessions: updatedSessions
        )
    }
}
