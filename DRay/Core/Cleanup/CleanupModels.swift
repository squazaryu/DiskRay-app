import Foundation

enum CleanupRiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
}

struct CleanupItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64
    let confidenceScore: Double
    let explainability: String

    init(url: URL, sizeInBytes: Int64, confidenceScore: Double = 0.7, explainability: String = "Matched analyzer cleanup rules.") {
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.confidenceScore = confidenceScore
        self.explainability = explainability
    }

    var name: String { url.lastPathComponent }
}

struct CleanupCategoryResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let key: String
    let title: String
    let description: String
    let isSafeByDefault: Bool
    let riskLevel: CleanupRiskLevel
    let recommendationReason: String
    let confidenceScore: Double
    let explainability: String
    let items: [CleanupItem]

    init(
        key: String,
        title: String,
        description: String,
        isSafeByDefault: Bool,
        riskLevel: CleanupRiskLevel,
        recommendationReason: String,
        confidenceScore: Double = 0.7,
        explainability: String = "Category selected by analyzer based on age/path heuristics.",
        items: [CleanupItem]
    ) {
        self.key = key
        self.title = title
        self.description = description
        self.isSafeByDefault = isSafeByDefault
        self.riskLevel = riskLevel
        self.recommendationReason = recommendationReason
        self.confidenceScore = confidenceScore
        self.explainability = explainability
        self.items = items
    }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct SmartScanResult: Sendable {
    let categories: [CleanupCategoryResult]
    let analyzerTelemetry: [CleanupAnalyzerTelemetry]

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }

    var totalItems: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
}

struct CleanupAnalyzerTelemetry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let key: String
    let title: String
    let durationMs: Int
    let itemCount: Int
    let totalBytes: Int64
    let skipped: Bool
}

struct CleanupExecutionResult: Sendable {
    let moved: Int
    let failed: Int
}
