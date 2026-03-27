import Foundation

struct StartupEntry: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let source: String
    let sizeInBytes: Int64
}

struct PerformanceRecommendation: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let details: String
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
