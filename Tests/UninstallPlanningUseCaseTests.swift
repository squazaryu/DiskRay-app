import Foundation
import Testing
@testable import DRay

struct UninstallPlanningUseCaseTests {
    @Test
    func previewBuildsAppBundleAndRiskSortedRemnants() {
        let useCase = UninstallPlanningUseCase()
        let app = InstalledApp(
            name: "Demo",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/Demo.app")
        )
        let remnants = [
            AppRemnant(url: URL(fileURLWithPath: "/Users/test/Library/Caches/com.example.demo"), sizeInBytes: 100),
            AppRemnant(url: URL(fileURLWithPath: "/Library/LaunchAgents/com.example.demo.plist"), sizeInBytes: 200),
            AppRemnant(url: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.demo.helper.plist"), sizeInBytes: 300)
        ]

        let preview = useCase.uninstallPreview(app: app, remnants: remnants)

        #expect(preview.count == 4)
        #expect(preview.first?.type == .appBundle)
        #expect(preview.dropFirst().map(\.sizeInBytes) == [300, 200, 100])
        #expect(preview[1].risk == .high)
        #expect(preview[2].risk == .medium)
        #expect(preview[3].risk == .low)
    }

    @Test
    func verifyReportExplainsSkippedFailedAndNotSelectedItems() {
        let useCase = UninstallPlanningUseCase()
        let app = InstalledApp(
            name: "Demo",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/Demo.app")
        )

        let skippedURL = URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.demo.helper.plist")
        let failedURL = URL(fileURLWithPath: "/Users/test/Library/Caches/com.example.demo/cache.db")
        let notSelectedURL = URL(fileURLWithPath: "/Users/test/Library/Logs/com.example.demo/log.txt")

        let preview = [
            UninstallPreviewItem(
                url: skippedURL,
                type: .remnant,
                sizeInBytes: 11,
                risk: .high,
                reason: "System-level helper or daemon"
            ),
            UninstallPreviewItem(
                url: failedURL,
                type: .remnant,
                sizeInBytes: 22,
                risk: .low,
                reason: "Regular app support/caches/logs"
            )
        ]
        let validation = UninstallValidationReport(
            appName: app.name,
            createdAt: Date(timeIntervalSince1970: 1_726_000_000),
            results: [
                UninstallActionResult(
                    url: skippedURL,
                    type: .remnant,
                    status: .skippedProtected,
                    trashedPath: nil,
                    details: nil
                ),
                UninstallActionResult(
                    url: failedURL,
                    type: .remnant,
                    status: .failed,
                    trashedPath: nil,
                    details: "Permission denied"
                )
            ]
        )
        let remaining = [
            AppRemnant(url: skippedURL, sizeInBytes: 11),
            AppRemnant(url: failedURL, sizeInBytes: 22),
            AppRemnant(url: notSelectedURL, sizeInBytes: 33)
        ]

        let report = useCase.buildVerifyReport(
            app: app,
            previewItems: preview,
            validation: validation,
            remaining: remaining,
            isProtectedPath: { _ in false },
            isAppRunning: false
        )

        #expect(report.attemptedItems == 2)
        #expect(report.removedItems == 0)
        #expect(report.remaining.count == 3)

        let byPath = Dictionary(uniqueKeysWithValues: report.remaining.map { ($0.url.path, $0.reason) })
        #expect(byPath[skippedURL.path]?.contains("system-protected path") == true)
        #expect(byPath[failedURL.path]?.contains("Permission denied") == true)
        #expect(byPath[notSelectedURL.path]?.contains("Not selected for removal") == true)
    }
}
