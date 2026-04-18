import Foundation

enum RootUnifiedScanCoordinator {
    static func buildSummary(
        smartResult: SmartScanResult,
        privacyReport: PrivacyScanReport,
        performanceReport: PerformanceReport,
        finishedAt: Date = Date()
    ) -> UnifiedScanSummary {
        UnifiedScanSummary(
            smartCareCategories: smartResult.categories.count,
            smartCareBytes: smartResult.totalBytes,
            privacyCategories: privacyReport.categories.count,
            privacyBytes: privacyReport.totalBytes,
            startupEntries: performanceReport.startupEntries.count,
            startupBytes: performanceReport.startupTotalBytes,
            finishedAt: finishedAt
        )
    }

    static func completionMessage(
        smartResult: SmartScanResult,
        privacyReport: PrivacyScanReport,
        performanceReport: PerformanceReport
    ) -> String {
        "Unified scan done: smart \(smartResult.categories.count), privacy \(privacyReport.categories.count), startup \(performanceReport.startupEntries.count)"
    }
}
