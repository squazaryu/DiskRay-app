import Foundation

actor SmartScanService: SmartCareServicing {
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

    func runSmartScan(
        excludedPrefixes: [String],
        excludedAnalyzerKeys: [String] = [],
        onProgress: (@Sendable (SmartScanProgress) async -> Void)? = nil
    ) async -> SmartScanResult {
        let excluded = Set(excludedAnalyzerKeys)
        var categories: [CleanupCategoryResult] = []
        var telemetry: [CleanupAnalyzerTelemetry] = []
        categories.reserveCapacity(analyzers.count)
        telemetry.reserveCapacity(analyzers.count)

        for (index, analyzer) in analyzers.enumerated() {
            let progress = SmartScanProgress(
                analyzerKey: analyzer.key,
                analyzerTitle: analyzer.title,
                index: index + 1,
                total: analyzers.count,
                skipped: excluded.contains(analyzer.key)
            )
            if let onProgress {
                await onProgress(progress)
            }
            if excluded.contains(analyzer.key) {
                telemetry.append(
                    CleanupAnalyzerTelemetry(
                        key: analyzer.key,
                        title: analyzer.title,
                        durationMs: 0,
                        itemCount: 0,
                        totalBytes: 0,
                        skipped: true
                    )
                )
                continue
            }
            let started = DispatchTime.now().uptimeNanoseconds
            let result = await analyzer.analyze(excludedPrefixes: excludedPrefixes)
            let elapsed = DispatchTime.now().uptimeNanoseconds - started
            categories.append(result)
            telemetry.append(
                CleanupAnalyzerTelemetry(
                    key: analyzer.key,
                    title: analyzer.title,
                    durationMs: Int(elapsed / 1_000_000),
                    itemCount: result.items.count,
                    totalBytes: result.totalBytes,
                    skipped: false
                )
            )
        }

        return SmartScanResult(
            categories: categories.sorted { $0.totalBytes > $1.totalBytes },
            analyzerTelemetry: telemetry.sorted { $0.durationMs > $1.durationMs }
        )
    }

    func clean(
        items: [CleanupItem],
        minSizeBytes: Int64,
        onProgress: (@Sendable (SmartCleanupProgress) async -> Void)? = nil
    ) async -> CleanupExecutionResult {
        var moved = 0
        var failed = 0
        let candidates = items.filter { $0.sizeInBytes >= minSizeBytes }
        let total = candidates.count

        for (index, item) in candidates.enumerated() {
            let path = item.url.path
            if protectedPathPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                failed += 1
                if let onProgress {
                    await onProgress(
                        SmartCleanupProgress(
                            processed: index + 1,
                            total: total,
                            moved: moved,
                            failed: failed,
                            currentItemName: item.name
                        )
                    )
                }
                continue
            }
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashedURL)
                moved += 1
            } catch {
                failed += 1
            }
            if let onProgress {
                await onProgress(
                    SmartCleanupProgress(
                        processed: index + 1,
                        total: total,
                        moved: moved,
                        failed: failed,
                        currentItemName: item.name
                    )
                )
            }
        }

        return CleanupExecutionResult(moved: moved, failed: failed)
    }
}
