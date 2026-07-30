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

enum UninstallMode: String, Codable, Sendable {
    case standard
    case clean
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

enum UninstallRemovalMethod: String, Codable, Sendable {
    case removedByStandardTrash
    case removedByFinderRecycle
    case removedByAdminTrash
    case forceRemovedByAdmin
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
    case launchDaemon
    case privilegedHelper
    case protectedBySystem
    case unknown
}

enum UninstallRemainingIssueCategory: String, Codable, Sendable {
    case launchDaemon
    case privilegedHelper
    case systemProtected
    case permissionDenied
    case preference
    case appBundle
    case remnant
    case missing
    case manualActionRequired
    case other
}

enum UninstallRemainingRemediation: String, Codable, Sendable {
    case unloadAndRetryWithAdministrator
    case keepExcludedOrHandleOutsideDRay
    case grantFullDiskAccessAndRetry
    case reviewPreferenceAndClean
    case retryWithAdministrator
    case removeResolvedRecord
    case quitOwnerAndRetry
    case inspectAndRetry
}

struct UninstallRemainingIssueClassification: Sendable {
    let category: UninstallRemainingIssueCategory
    let remediation: UninstallRemainingRemediation
}

enum UninstallRemainingIssueClassifier {
    static func classify(
        path rawPath: String,
        reason: String,
        failureCategory: UninstallFailureCategory? = nil,
        itemType: UninstallItemType? = nil
    ) -> UninstallRemainingIssueClassification {
        let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path
        let lowerPath = path.lowercased()
        let lowerReason = reason.lowercased()

        if failureCategory == .launchDaemon || lowerPath.contains("/library/launchdaemons/") {
            return classification(.launchDaemon, .unloadAndRetryWithAdministrator)
        }
        if failureCategory == .privilegedHelper || lowerPath.contains("/library/privilegedhelpertools/") {
            return classification(.privilegedHelper, .unloadAndRetryWithAdministrator)
        }
        if PathSafetyPolicy.isUserPreferenceStatePath(path) {
            return classification(.preference, .reviewPreferenceAndClean)
        }
        if failureCategory == .protectedBySystem || PathSafetyPolicy.isProtected(path) {
            return classification(.systemProtected, .keepExcludedOrHandleOutsideDRay)
        }
        if failureCategory == .permissionDenied
            || lowerReason.contains("permission denied")
            || lowerReason.contains("access denied")
            || lowerReason.contains("not permitted")
            || lowerReason.contains("authorization")
        {
            return classification(.permissionDenied, .grantFullDiskAccessAndRetry)
        }
        if failureCategory == .runningProcessLock
            || lowerReason.contains("running process")
            || lowerReason.contains("running app")
            || lowerReason.contains("recreated")
        {
            return classification(.manualActionRequired, .quitOwnerAndRetry)
        }
        if itemType == .appBundle || lowerPath.hasSuffix(".app") {
            return classification(.appBundle, .retryWithAdministrator)
        }
        if lowerReason.contains("missing") || lowerReason.contains("no longer exists") {
            return classification(.missing, .removeResolvedRecord)
        }
        if failureCategory != nil && failureCategory != .unknown {
            return classification(.manualActionRequired, .inspectAndRetry)
        }
        if lowerPath.contains("/library/") {
            return classification(.remnant, .inspectAndRetry)
        }
        return classification(.other, .inspectAndRetry)
    }

    private static func classification(
        _ category: UninstallRemainingIssueCategory,
        _ remediation: UninstallRemainingRemediation
    ) -> UninstallRemainingIssueClassification {
        UninstallRemainingIssueClassification(category: category, remediation: remediation)
    }
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
    let removalMethod: UninstallRemovalMethod?

    init(
        url: URL,
        type: UninstallItemType,
        status: UninstallActionStatus,
        trashedPath: String?,
        details: String?,
        failureCategory: UninstallFailureCategory? = nil,
        remediationHint: String? = nil,
        removalMethod: UninstallRemovalMethod? = nil
    ) {
        self.url = url
        self.type = type
        self.status = status
        self.trashedPath = trashedPath
        self.details = details
        self.failureCategory = failureCategory
        self.remediationHint = remediationHint
        self.removalMethod = removalMethod ?? Self.defaultRemovalMethod(for: status)
    }

    enum CodingKeys: String, CodingKey {
        case url, type, status, trashedPath, details, failureCategory, remediationHint, removalMethod
    }

    private static func defaultRemovalMethod(for status: UninstallActionStatus) -> UninstallRemovalMethod? {
        switch status {
        case .removed:
            return nil
        case .skippedProtected:
            return .skippedProtected
        case .missing:
            return .missing
        case .failed:
            return .failed
        }
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

enum UninstallOwnershipConfidence: String, Codable, Hashable, Sendable {
    case low
    case medium
    case high
}

enum UninstallOwnershipEvidenceKind: String, Codable, Hashable, Sendable {
    case exactPathIdentity
    case packageReceipt
    case identifierPattern
    case ambiguousIdentifiers
    case sharedContainer
}

struct UninstallOwnershipEvidence: Codable, Hashable, Sendable {
    let kind: UninstallOwnershipEvidenceKind
    let details: String
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
    let category: UninstallRemainingIssueCategory
    let remediation: UninstallRemainingRemediation
    let ownershipConfidence: UninstallOwnershipConfidence?
    let ownershipEvidence: [UninstallOwnershipEvidence]

    init(
        url: URL,
        sizeInBytes: Int64,
        reason: String,
        risk: UninstallRiskLevel,
        category: UninstallRemainingIssueCategory? = nil,
        remediation: UninstallRemainingRemediation? = nil,
        failureCategory: UninstallFailureCategory? = nil,
        itemType: UninstallItemType? = nil,
        ownershipConfidence: UninstallOwnershipConfidence? = nil,
        ownershipEvidence: [UninstallOwnershipEvidence] = []
    ) {
        let inferred = UninstallRemainingIssueClassifier.classify(
            path: url.path,
            reason: reason,
            failureCategory: failureCategory,
            itemType: itemType
        )
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.reason = reason
        self.risk = risk
        self.category = category ?? inferred.category
        self.remediation = remediation ?? inferred.remediation
        self.ownershipConfidence = ownershipConfidence
        self.ownershipEvidence = ownershipEvidence
    }

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

struct UninstallRemainingIssueRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let path: String
    let sizeInBytes: Int64
    let reason: String
    let risk: UninstallRiskLevel
    let category: UninstallRemainingIssueCategory
    let remediation: UninstallRemainingRemediation
    let ownershipConfidence: UninstallOwnershipConfidence?
    let ownershipEvidence: [UninstallOwnershipEvidence]

    init(
        id: UUID = UUID(),
        path: String,
        sizeInBytes: Int64,
        reason: String,
        risk: UninstallRiskLevel,
        category: UninstallRemainingIssueCategory? = nil,
        remediation: UninstallRemainingRemediation? = nil,
        ownershipConfidence: UninstallOwnershipConfidence? = nil,
        ownershipEvidence: [UninstallOwnershipEvidence] = []
    ) {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let inferred = UninstallRemainingIssueClassifier.classify(
            path: standardizedPath,
            reason: reason
        )
        self.id = id
        self.path = standardizedPath
        self.sizeInBytes = sizeInBytes
        self.reason = reason
        self.risk = risk
        self.category = category ?? inferred.category
        self.remediation = remediation ?? inferred.remediation
        self.ownershipConfidence = ownershipConfidence
        self.ownershipEvidence = ownershipEvidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPath = try container.decode(String.self, forKey: .path)
        let decodedReason = try container.decode(String.self, forKey: .reason)
        let standardizedPath = URL(fileURLWithPath: decodedPath).standardizedFileURL.path
        let inferred = UninstallRemainingIssueClassifier.classify(
            path: standardizedPath,
            reason: decodedReason
        )

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        path = standardizedPath
        sizeInBytes = try container.decode(Int64.self, forKey: .sizeInBytes)
        reason = decodedReason
        risk = try container.decode(UninstallRiskLevel.self, forKey: .risk)
        category = try container.decodeIfPresent(
            UninstallRemainingIssueCategory.self,
            forKey: .category
        ) ?? inferred.category
        remediation = try container.decodeIfPresent(
            UninstallRemainingRemediation.self,
            forKey: .remediation
        ) ?? inferred.remediation
        ownershipConfidence = try container.decodeIfPresent(
            UninstallOwnershipConfidence.self,
            forKey: .ownershipConfidence
        )
        ownershipEvidence = try container.decodeIfPresent(
            [UninstallOwnershipEvidence].self,
            forKey: .ownershipEvidence
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encode(sizeInBytes, forKey: .sizeInBytes)
        try container.encode(reason, forKey: .reason)
        try container.encode(risk, forKey: .risk)
        try container.encode(category, forKey: .category)
        try container.encode(remediation, forKey: .remediation)
        try container.encodeIfPresent(ownershipConfidence, forKey: .ownershipConfidence)
        try container.encode(ownershipEvidence, forKey: .ownershipEvidence)
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var name: String {
        url.lastPathComponent
    }

    var allowsAutomaticCleanup: Bool {
        ownershipConfidence == nil || ownershipConfidence == .high
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case path
        case sizeInBytes
        case reason
        case risk
        case category
        case remediation
        case ownershipConfidence
        case ownershipEvidence
    }
}

struct UninstallRemainingRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let bundleID: String?
    let updatedAt: Date
    let issues: [UninstallRemainingIssueRecord]

    init(
        id: UUID = UUID(),
        appName: String,
        bundleID: String?,
        updatedAt: Date,
        issues: [UninstallRemainingIssueRecord]
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.updatedAt = updatedAt
        self.issues = issues
    }

    var remainingCount: Int {
        issues.count
    }

    var totalSizeInBytes: Int64 {
        issues.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct UninstallObservedApp: Codable, Hashable, Sendable {
    let appName: String
    let bundleID: String
    let appPath: String
    let observedAt: Date
}

struct UninstallRemovedAppCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let bundleID: String?
    let lastKnownAppPath: String?
    let detectedAt: Date

    init(
        id: UUID = UUID(),
        appName: String,
        bundleID: String?,
        lastKnownAppPath: String?,
        detectedAt: Date
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.lastKnownAppPath = lastKnownAppPath
        self.detectedAt = detectedAt
    }
}

struct UninstallDeepSweepCandidate: Sendable {
    let appName: String
    let bundleID: String
    let issues: [UninstallVerifyIssue]

    var totalSizeInBytes: Int64 {
        issues.reduce(0) { $0 + $1.sizeInBytes }
    }
}
