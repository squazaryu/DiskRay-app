import Foundation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let bundleID: String
    let appURL: URL
}

struct AppRemnant: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64

    var name: String { url.lastPathComponent }
}

enum UninstallItemType: String, Codable, Sendable {
    case appBundle
    case remnant
}

enum UninstallActionStatus: String, Codable, Sendable {
    case removed
    case skippedProtected
    case missing
    case failed
}

enum UninstallFailureCategory: String, Codable, Sendable {
    case permissionDenied
    case appStoreManaged
    case itemLocked
    case readOnlyVolume
    case runningProcessLock
    case protectedBySystem
    case unknown
}

struct UninstallActionResult: Identifiable, Codable, Sendable {
    let id = UUID()
    let url: URL
    let type: UninstallItemType
    let status: UninstallActionStatus
    let trashedPath: String?
    let details: String?
    let failureCategory: UninstallFailureCategory?
    let remediationHint: String?

    init(
        url: URL,
        type: UninstallItemType,
        status: UninstallActionStatus,
        trashedPath: String?,
        details: String?,
        failureCategory: UninstallFailureCategory? = nil,
        remediationHint: String? = nil
    ) {
        self.url = url
        self.type = type
        self.status = status
        self.trashedPath = trashedPath
        self.details = details
        self.failureCategory = failureCategory
        self.remediationHint = remediationHint
    }

    enum CodingKeys: String, CodingKey {
        case url, type, status, trashedPath, details, failureCategory, remediationHint
    }
}

struct UninstallValidationReport: Codable, Sendable {
    let appName: String
    let createdAt: Date
    let results: [UninstallActionResult]

    var removedCount: Int {
        results.filter { $0.status == .removed }.count
    }

    var skippedCount: Int {
        results.filter { $0.status == .skippedProtected || $0.status == .missing }.count
    }

    var failedCount: Int {
        results.filter { $0.status == .failed }.count
    }
}

enum UninstallRiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
}

struct UninstallPreviewItem: Identifiable, Codable, Sendable {
    let id = UUID()
    let url: URL
    let type: UninstallItemType
    let sizeInBytes: Int64
    let risk: UninstallRiskLevel
    let reason: String

    enum CodingKeys: String, CodingKey {
        case url, type, sizeInBytes, risk, reason
    }
}

struct UninstallRollbackItem: Identifiable, Codable, Sendable {
    let id = UUID()
    let originalPath: String
    let trashedPath: String
    let type: UninstallItemType

    var name: String {
        URL(fileURLWithPath: originalPath).lastPathComponent
    }

    enum CodingKeys: String, CodingKey {
        case originalPath, trashedPath, type
    }
}

struct UninstallSession: Identifiable, Codable, Sendable {
    let id = UUID()
    let appName: String
    let createdAt: Date
    let rollbackItems: [UninstallRollbackItem]

    enum CodingKeys: String, CodingKey {
        case appName, createdAt, rollbackItems
    }
}

struct UninstallVerifyIssue: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64
    let reason: String
    let risk: UninstallRiskLevel

    var name: String {
        url.lastPathComponent
    }
}

enum UninstallStartupReferenceSource: String, Sendable {
    case userLaunchAgent
    case systemLaunchAgent
    case systemLaunchDaemon
    case startupItems
    case loginItems
    case backgroundItems
    case unknown

    var title: String {
        switch self {
        case .userLaunchAgent: return "User LaunchAgent"
        case .systemLaunchAgent: return "System LaunchAgent"
        case .systemLaunchDaemon: return "System LaunchDaemon"
        case .startupItems: return "Startup Item"
        case .loginItems: return "Login Item"
        case .backgroundItems: return "Background Task"
        case .unknown: return "Startup Reference"
        }
    }
}

struct UninstallStartupReference: Identifiable, Hashable, Sendable {
    let id = UUID()
    let source: UninstallStartupReferenceSource
    let url: URL?
    let details: String
    let reason: String

    var displayPath: String {
        if let url {
            return url.path
        }
        return details
    }
}

struct UninstallVerifyReport: Sendable {
    let appName: String
    let createdAt: Date
    let attemptedItems: Int
    let removedItems: Int
    let remaining: [UninstallVerifyIssue]
    let startupReferences: [UninstallStartupReference]

    var remainingCount: Int {
        remaining.count
    }

    var startupReferenceCount: Int {
        startupReferences.count
    }
}
