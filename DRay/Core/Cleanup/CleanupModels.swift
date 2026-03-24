import Foundation

struct CleanupItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64

    var name: String { url.lastPathComponent }
}

struct CleanupCategoryResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let key: String
    let title: String
    let description: String
    let isSafeByDefault: Bool
    let items: [CleanupItem]

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct SmartScanResult: Sendable {
    let categories: [CleanupCategoryResult]

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }

    var totalItems: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
}

struct CleanupExecutionResult: Sendable {
    let moved: Int
    let failed: Int
}
