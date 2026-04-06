import Foundation

enum QuickActionModule: String, Codable, Sendable {
    case performance
    case privacy
}

enum QuickActionRollbackKind: String, Codable, Sendable {
    case none
    case restorePriorities
}

struct QuickActionDeltaReport: Identifiable, Codable, Sendable {
    let id: UUID
    let module: QuickActionModule
    let actionTitle: String
    let beforeItems: Int
    let beforeBytes: Int64
    let afterItems: Int
    let afterBytes: Int64
    let moved: Int
    let failed: Int
    let skippedProtected: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        module: QuickActionModule,
        actionTitle: String,
        beforeItems: Int,
        beforeBytes: Int64,
        afterItems: Int,
        afterBytes: Int64,
        moved: Int,
        failed: Int,
        skippedProtected: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.module = module
        self.actionTitle = actionTitle
        self.beforeItems = beforeItems
        self.beforeBytes = beforeBytes
        self.afterItems = afterItems
        self.afterBytes = afterBytes
        self.moved = moved
        self.failed = failed
        self.skippedProtected = skippedProtected
        self.createdAt = createdAt
    }

    var reclaimedBytes: Int64 {
        max(0, beforeBytes - afterBytes)
    }

    var reducedItems: Int {
        max(0, beforeItems - afterItems)
    }
}

struct QuickActionRollbackSession: Identifiable, Codable, Sendable {
    let id: UUID
    let module: QuickActionModule
    let actionTitle: String
    let createdAt: Date
    let rollbackKind: QuickActionRollbackKind
    let adjustedTargets: [String]
    var restoredAt: Date?
    var rollbackSummary: String?

    init(
        id: UUID = UUID(),
        module: QuickActionModule,
        actionTitle: String,
        createdAt: Date = Date(),
        rollbackKind: QuickActionRollbackKind,
        adjustedTargets: [String],
        restoredAt: Date? = nil,
        rollbackSummary: String? = nil
    ) {
        self.id = id
        self.module = module
        self.actionTitle = actionTitle
        self.createdAt = createdAt
        self.rollbackKind = rollbackKind
        self.adjustedTargets = adjustedTargets
        self.restoredAt = restoredAt
        self.rollbackSummary = rollbackSummary
    }

    var canRollback: Bool {
        rollbackKind != .none && restoredAt == nil
    }
}
