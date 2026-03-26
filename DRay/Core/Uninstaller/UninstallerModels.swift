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

enum UninstallItemType: String, Sendable {
    case appBundle
    case remnant
}

enum UninstallActionStatus: String, Sendable {
    case removed
    case skippedProtected
    case missing
    case failed
}

struct UninstallActionResult: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let type: UninstallItemType
    let status: UninstallActionStatus
    let details: String?
}

struct UninstallValidationReport: Sendable {
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

enum UninstallRiskLevel: String, Sendable {
    case low
    case medium
    case high
}

struct UninstallPreviewItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let type: UninstallItemType
    let sizeInBytes: Int64
    let risk: UninstallRiskLevel
    let reason: String
}
