import Foundation
import Testing
@testable import DRay

struct UninstallerUseCaseTests {
    @Test
    @MainActor
    func uninstallAndVerifyRunsValidationThenBuildsVerifyReport() async {
        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let previewItems = [
            UninstallPreviewItem(
                url: app.appURL,
                type: .appBundle,
                sizeInBytes: 0,
                risk: .high,
                reason: "Main bundle"
            ),
            UninstallPreviewItem(
                url: URL(fileURLWithPath: "/Users/test/Library/Preferences/com.example.demo.plist"),
                type: .remnant,
                sizeInBytes: 1024,
                risk: .low,
                reason: "Preference"
            )
        ]
        let validation = UninstallValidationReport(
            appName: app.name,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            results: [
                UninstallActionResult(
                    url: app.appURL,
                    type: .appBundle,
                    status: .removed,
                    trashedPath: "/Users/test/.Trash/DemoApp.app",
                    details: nil
                ),
                UninstallActionResult(
                    url: URL(fileURLWithPath: "/Users/test/Library/Preferences/com.example.demo.plist"),
                    type: .remnant,
                    status: .failed,
                    trashedPath: nil,
                    details: "permission denied"
                )
            ]
        )
        let remaining = [
            AppRemnant(
                url: URL(fileURLWithPath: "/Users/test/Library/Preferences/com.example.demo.plist"),
                sizeInBytes: 1024
            )
        ]
        let service = UninstallerServiceStub(validation: validation, remnants: remaining)
        let useCase = UninstallerUseCase(service: service)

        let result = await useCase.uninstallAndVerify(
            app: app,
            previewItems: previewItems,
            isProtectedPath: { _ in false },
            isAppRunning: false
        )

        #expect(result.validation.appName == app.name)
        #expect(result.remainingRemnants.count == 1)
        #expect(result.verifyReport.remainingCount == 1)
        #expect(result.verifyReport.remaining.first?.reason.contains("Failed to remove") == true)

        let calls = await service.calls()
        #expect(calls == ["uninstall", "findRemnants"])
    }

    @Test
    @MainActor
    func runVerifyPassUsesProvidedValidation() async {
        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let previewItems = [
            UninstallPreviewItem(
                url: URL(fileURLWithPath: "/Users/test/Library/LaunchAgents/com.example.demo.plist"),
                type: .remnant,
                sizeInBytes: 2048,
                risk: .medium,
                reason: "Auto-start component"
            )
        ]
        let validation = UninstallValidationReport(
            appName: app.name,
            createdAt: Date(),
            results: [
                UninstallActionResult(
                    url: previewItems[0].url,
                    type: .remnant,
                    status: .skippedProtected,
                    trashedPath: nil,
                    details: nil
                )
            ]
        )
        let remaining = [
            AppRemnant(url: previewItems[0].url, sizeInBytes: 2048)
        ]
        let service = UninstallerServiceStub(validation: validation, remnants: remaining)
        let useCase = UninstallerUseCase(service: service)

        let result = await useCase.runVerifyPass(
            app: app,
            previewItems: previewItems,
            validation: validation,
            isProtectedPath: { _ in true },
            isAppRunning: true
        )

        #expect(result.remainingRemnants.count == 1)
        #expect(result.verifyReport.remaining.first?.reason == "Skipped: system-protected path (SIP/TCC).")
        #expect(result.verifyReport.attemptedItems == 1)

        let calls = await service.calls()
        #expect(calls == ["findRemnants"])
    }
}

private actor UninstallerServiceStub: UninstallerServicing {
    private let validation: UninstallValidationReport
    private let remnants: [AppRemnant]
    private var recordedCalls: [String] = []

    init(validation: UninstallValidationReport, remnants: [AppRemnant]) {
        self.validation = validation
        self.remnants = remnants
    }

    func installedApps() async -> [InstalledApp] {
        []
    }

    func findRemnants(for app: InstalledApp) async -> [AppRemnant] {
        recordedCalls.append("findRemnants")
        return remnants
    }

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        recordedCalls.append("uninstall")
        return validation
    }

    func calls() -> [String] {
        recordedCalls
    }
}
