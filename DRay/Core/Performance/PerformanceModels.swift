import Foundation

struct StartupEntry: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let source: String
    let sizeInBytes: Int64
}

enum PerformanceRecommendationAction: String, Sendable {
    case selectAllStartup
    case selectHeavyStartup
    case openSmartCare
    case runDiagnostics
    case none
}

struct PerformanceRecommendation: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let details: String
    let action: PerformanceRecommendationAction

    var actionTitle: String? {
        switch action {
        case .selectAllStartup:
            return "Select Startup Entries"
        case .selectHeavyStartup:
            return "Select Heavy Entries"
        case .openSmartCare:
            return "Open Smart Care"
        case .runDiagnostics:
            return "Re-run Diagnostics"
        case .none:
            return nil
        }
    }
}

struct PerformanceReport: Sendable {
    let generatedAt: Date
    let startupEntries: [StartupEntry]
    let diskFreeBytes: Int64?
    let diskTotalBytes: Int64?
    let recommendations: [PerformanceRecommendation]

    var startupTotalBytes: Int64 {
        startupEntries.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct StartupCleanupReport: Sendable {
    let moved: Int
    let failed: Int
    let skippedProtected: Int
}

struct LoadReliefResult: Sendable {
    let adjusted: [String]
    let skipped: [String]
    let failed: [String]
}
