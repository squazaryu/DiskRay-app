import Foundation

actor SmartScanService {
    private let analyzers: [CleanupAnalyzer]
    private let protectedPathPrefixes = ["/System", "/Library", "/bin", "/sbin", "/usr", "/private/var", "/private/etc"]

    init(analyzers: [CleanupAnalyzer] = [
        UserLogsAnalyzer(),
        UserCachesAnalyzer(),
        OldDownloadsAnalyzer(),
        XcodeDerivedDataAnalyzer(),
        IOSBackupsAnalyzer(),
        MailDownloadsAnalyzer(),
        LanguageFilesAnalyzer(),
        OrphanPreferencesAnalyzer()
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

    func clean(items: [CleanupItem], minSizeBytes: Int64) async -> CleanupExecutionResult {
        var moved = 0
        var failed = 0

        for item in items {
            if item.sizeInBytes < minSizeBytes { continue }
            let path = item.url.path
            if protectedPathPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                failed += 1
                continue
            }
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
