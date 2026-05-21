import Foundation
import Testing
@testable import DRay

struct AppUninstallerServiceFallbackTests {
    @Test
    func standardTrashSuccessReportsStandardMethod() async {
        let app = testApp(path: "/Applications/Demo.app")
        let service = AppUninstallerService(
            operations: operations(
                standardTrash: { _ in "/Users/test/.Trash/Demo.app" }
            )
        )

        let report = await service.uninstall(
            app: app,
            previewItems: previewItems(for: app),
            allowForceRemove: false
        )

        #expect(report.results.count == 1)
        #expect(report.results[0].status == .removed)
        #expect(report.results[0].removalMethod == .removedByStandardTrash)
        #expect(report.results[0].trashedPath == "/Users/test/.Trash/Demo.app")
    }

    @Test
    func adminTrashFallbackReportsAdminMethod() async {
        let app = testApp(path: "/Applications/Demo.app")
        let service = AppUninstallerService(
            operations: operations(
                standardTrash: { _ in throw permissionError() },
                finderRecycle: { _ in AppUninstallerTrashResult(success: false, trashedPath: nil, details: "Finder denied") },
                adminTrash: { _ in AppUninstallerTrashResult(success: true, trashedPath: "/Users/test/.Trash/admin-Demo.app", details: "Admin moved") }
            )
        )

        let report = await service.uninstall(
            app: app,
            previewItems: previewItems(for: app),
            allowForceRemove: false
        )

        #expect(report.results.count == 1)
        #expect(report.results[0].status == .removed)
        #expect(report.results[0].removalMethod == .removedByAdminTrash)
        #expect(report.results[0].trashedPath == "/Users/test/.Trash/admin-Demo.app")
    }

    @Test
    func forceRemoveRunsOnlyWhenHighRiskModeAllowsIt() async {
        let app = testApp(path: "/Applications/AppStoreDemo.app")
        let service = AppUninstallerService(
            operations: operations(
                standardTrash: { _ in throw permissionError() },
                finderRecycle: { _ in AppUninstallerTrashResult(success: false, trashedPath: nil, details: "Finder denied") },
                adminTrash: { _ in AppUninstallerTrashResult(success: false, trashedPath: nil, details: "Admin trash denied") },
                adminHardRemove: { _ in AppUninstallerHardRemoveResult(success: true, details: "Admin hard remove completed") }
            )
        )

        let disabledReport = await service.uninstall(
            app: app,
            previewItems: previewItems(for: app),
            allowForceRemove: false
        )
        let enabledReport = await service.uninstall(
            app: app,
            previewItems: previewItems(for: app),
            allowForceRemove: true
        )

        #expect(disabledReport.results[0].status == .failed)
        #expect(disabledReport.results[0].removalMethod == .failed)
        #expect(disabledReport.results[0].details?.contains("high-risk deletion is disabled") == true)
        #expect(enabledReport.results[0].status == .removed)
        #expect(enabledReport.results[0].removalMethod == .forceRemovedByAdmin)
    }

    @Test
    func verifyReportPreservesUnresolvedAppBundleForRemainingCleanup() {
        let useCase = UninstallPlanningUseCase()
        let app = testApp(path: "/Applications/Demo.app")
        let preview = previewItems(for: app)
        let validation = UninstallValidationReport(
            appName: app.name,
            createdAt: Date(),
            results: [
                UninstallActionResult(
                    url: app.appURL,
                    type: .appBundle,
                    status: .failed,
                    trashedPath: nil,
                    details: "Admin trash denied",
                    failureCategory: .appStoreManaged,
                    remediationHint: "Enable high-risk deletion or remove manually.",
                    removalMethod: .failed
                )
            ]
        )

        let report = useCase.buildVerifyReport(
            app: app,
            previewItems: preview,
            validation: validation,
            remaining: [],
            isProtectedPath: { _ in false },
            isAppRunning: false,
            fileExists: { $0 == app.appURL.path }
        )

        #expect(report.remainingCount == 1)
        #expect(report.remaining[0].url.path == app.appURL.path)
        #expect(report.remaining[0].reason.contains("Admin trash denied"))
    }

    private func testApp(path: String) -> InstalledApp {
        InstalledApp(
            name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: path)
        )
    }

    private func previewItems(for app: InstalledApp) -> [UninstallPreviewItem] {
        [
            UninstallPreviewItem(
                url: app.appURL,
                type: .appBundle,
                sizeInBytes: 0,
                risk: .high,
                reason: "Main bundle"
            )
        ]
    }

    private func operations(
        fileExists: @escaping @Sendable (String) -> Bool = { _ in true },
        standardTrash: @escaping @Sendable (URL) throws -> String? = { _ in throw permissionError() },
        finderRecycle: @escaping @Sendable (URL) async -> AppUninstallerTrashResult = { _ in AppUninstallerTrashResult(success: false, trashedPath: nil, details: "Finder denied") },
        adminTrash: @escaping @Sendable (URL) -> AppUninstallerTrashResult = { _ in AppUninstallerTrashResult(success: false, trashedPath: nil, details: "Admin trash denied") },
        adminHardRemove: @escaping @Sendable (URL) -> AppUninstallerHardRemoveResult = { _ in AppUninstallerHardRemoveResult(success: false, details: "Admin hard remove denied") }
    ) -> AppUninstallerOperations {
        AppUninstallerOperations(
            fileExists: fileExists,
            standardTrash: standardTrash,
            finderRecycle: finderRecycle,
            adminTrash: adminTrash,
            adminHardRemove: adminHardRemove
        )
    }

}

private func permissionError() -> NSError {
    NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
}
