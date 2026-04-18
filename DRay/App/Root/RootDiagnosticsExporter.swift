import Foundation

struct RootOperationLogExportResult {
    let exportedURL: URL?
    let telemetryMessage: String
}

struct RootDiagnosticReportExportResult {
    let exportedURL: URL?
    let telemetryMessage: String
}

@MainActor
enum RootDiagnosticsExporter {
    static func exportOperationLog(using operationLogs: OperationLogStore) -> RootOperationLogExportResult {
        let url = operationLogs.exportJSON()
        if let url {
            return RootOperationLogExportResult(
                exportedURL: url,
                telemetryMessage: "Exported operation log report to \(url.path)"
            )
        }
        return RootOperationLogExportResult(
            exportedURL: nil,
            telemetryMessage: "Failed to export operation log report"
        )
    }

    static func exportDiagnosticReport(
        selectedTargetPath: String,
        unifiedScanSummary: UnifiedScanSummary?,
        smartCareCategoryCount: Int,
        privacyCategoryCount: Int,
        startupEntryCount: Int,
        operationLogEntries: [OperationLogEntry],
        fileManager: FileManager = .default
    ) -> RootDiagnosticReportExportResult {
        let report = DiagnosticReport(
            generatedAt: Date(),
            selectedTargetPath: selectedTargetPath,
            unifiedScanSummary: unifiedScanSummary.map {
                UnifiedScanSnapshot(
                    smartCareCategories: $0.smartCareCategories,
                    smartCareBytes: $0.smartCareBytes,
                    privacyCategories: $0.privacyCategories,
                    privacyBytes: $0.privacyBytes,
                    startupEntries: $0.startupEntries,
                    startupBytes: $0.startupBytes,
                    finishedAt: $0.finishedAt
                )
            },
            smartCareCategoryCount: smartCareCategoryCount,
            privacyCategoryCount: privacyCategoryCount,
            startupEntryCount: startupEntryCount,
            operationLogs: operationLogEntries
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report),
              let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return RootDiagnosticReportExportResult(
                exportedURL: nil,
                telemetryMessage: "Failed to export diagnostic report"
            )
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = downloads.appendingPathComponent("dray-diagnostic-\(stamp).json")
        do {
            try data.write(to: url, options: [.atomic])
            return RootDiagnosticReportExportResult(
                exportedURL: url,
                telemetryMessage: "Exported diagnostic report to \(url.path)"
            )
        } catch {
            return RootDiagnosticReportExportResult(
                exportedURL: nil,
                telemetryMessage: "Failed to save diagnostic report"
            )
        }
    }
}
