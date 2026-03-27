import Foundation

enum PrivacyRisk: String, Sendable {
    case low
    case medium
    case high
}

struct PrivacyArtifact: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64
}

struct PrivacyCategory: Identifiable, Sendable {
    let id: String
    let title: String
    let details: String
    let risk: PrivacyRisk
    let artifacts: [PrivacyArtifact]

    var totalBytes: Int64 {
        artifacts.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct PrivacyScanReport: Sendable {
    let generatedAt: Date
    let categories: [PrivacyCategory]

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }
}

struct PrivacyCleanReport: Sendable {
    let moved: Int
    let failed: Int
    let skippedProtected: Int
    let cleanedBytes: Int64
}
