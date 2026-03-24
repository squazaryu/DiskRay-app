import Foundation

protocol CleanupAnalyzer: Sendable {
    var key: String { get }
    var title: String { get }
    var description: String { get }
    var isSafeByDefault: Bool { get }

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult
}
