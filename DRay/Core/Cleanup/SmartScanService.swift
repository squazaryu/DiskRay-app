import Foundation

actor SmartScanService {
    private let analyzers: [CleanupAnalyzer]

    init(analyzers: [CleanupAnalyzer] = [
        UserLogsAnalyzer(),
        UserCachesAnalyzer(),
        OldDownloadsAnalyzer(),
        XcodeDerivedDataAnalyzer(),
        IOSBackupsAnalyzer(),
        MailDownloadsAnalyzer()
    ]) {
        self.analyzers = analyzers
    }

    func runSmartScan(excludedPrefixes: [String]) async -> SmartScanResult {
        var categories: [CleanupCategoryResult] = []
        categories.reserveCapacity(analyzers.count)

        for analyzer in analyzers {
            let result = await analyzer.analyze(excludedPrefixes: excludedPrefixes)
            categories.append(result)
        }

        return SmartScanResult(categories: categories.sorted { $0.totalBytes > $1.totalBytes })
    }

    func clean(items: [CleanupItem]) async -> CleanupExecutionResult {
        var moved = 0
        var failed = 0

        for item in items {
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashedURL)
                moved += 1
            } catch {
                failed += 1
            }
        }

        return CleanupExecutionResult(moved: moved, failed: failed)
    }
}
