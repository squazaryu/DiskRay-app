import Foundation
import Testing
@testable import DRay

@MainActor
struct RepairFeatureControllerTests {
    @Test
    func loadArtifactsAndRunRepairUpdatesReportAndSessions() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let artifact = AppRemnant(
            url: URL(fileURLWithPath: "/Users/test/Library/Caches/com.example.demo/cache.db"),
            sizeInBytes: 8192
        )
        let validation = UninstallValidationReport(
            appName: app.name,
            createdAt: Date(),
            results: [
                UninstallActionResult(
                    url: artifact.url,
                    type: .remnant,
                    status: .removed,
                    trashedPath: "/Users/test/.Trash/cache.db",
                    details: nil
                )
            ]
        )
        let service = RepairControllerServiceStub(
            apps: [app],
            remnants: [artifact],
            validation: validation
        )
        let controller = makeController(tempDir: tempDir, service: service)

        controller.loadArtifacts(for: app)
        try await waitUntil("artifacts loaded") {
            !controller.state.isLoading && controller.state.artifacts.count == 1
        }

        var callbackReport: UninstallValidationReport?
        controller.runRepair(app: app, artifacts: controller.state.artifacts) { report in
            callbackReport = report
        }

        try await waitUntil("repair completed") {
            !controller.state.isLoading && controller.state.report != nil
        }

        #expect(callbackReport?.removedCount == 1)
        #expect(controller.state.sessions.count == 1)
    }

    @Test
    func recommendedArtifactsRespectsStrategyRiskLevels() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let lowRisk = AppRemnant(
            url: URL(fileURLWithPath: "/Users/test/Library/Caches/com.example.demo/cache.db"),
            sizeInBytes: 100
        )
        let highRisk = AppRemnant(
            url: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.demo.helper.plist"),
            sizeInBytes: 100
        )
        let service = RepairControllerServiceStub(
            apps: [app],
            remnants: [lowRisk, highRisk],
            validation: UninstallValidationReport(appName: app.name, createdAt: Date(), results: [])
        )
        let controller = makeController(tempDir: tempDir, service: service)
        controller.loadArtifacts(for: app)
        try await waitUntil("artifacts loaded for strategy check") {
            !controller.state.isLoading && controller.state.artifacts.count == 2
        }

        let safe = controller.recommendedArtifacts(for: .safeReset)
        let deep = controller.recommendedArtifacts(for: .deepReset)

        #expect(safe.count == 1)
        #expect(safe.first?.url.path == lowRisk.url.path)
        #expect(deep.count == 2)
    }

    private func makeController(
        tempDir: URL,
        service: RepairControllerServiceStub
    ) -> RepairFeatureController {
        let store = OperationalHistoryStore(directoryURL: tempDir)
        let sessionUseCase = UninstallSessionUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService()
        )
        let useCase = UninstallerUseCase(service: service)
        return RepairFeatureController(
            uninstallerUseCase: useCase,
            uninstallSessionUseCase: sessionUseCase
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-repair-controller-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func waitUntil(
        _ description: String,
        timeoutSeconds: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) async throws {
        let timeout = Date().addingTimeInterval(timeoutSeconds)
        while !condition(), Date() < timeout {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(condition(), "\(description) timed out")
    }
}

private actor RepairControllerServiceStub: UninstallerServicing {
    let apps: [InstalledApp]
    let remnants: [AppRemnant]
    let validation: UninstallValidationReport

    init(apps: [InstalledApp], remnants: [AppRemnant], validation: UninstallValidationReport) {
        self.apps = apps
        self.remnants = remnants
        self.validation = validation
    }

    func installedApps() async -> [InstalledApp] {
        apps
    }

    func findRemnants(for app: InstalledApp) async -> [AppRemnant] {
        remnants
    }

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        validation
    }
}
