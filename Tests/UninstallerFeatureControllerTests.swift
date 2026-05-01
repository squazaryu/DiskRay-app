import Foundation
import Testing
@testable import DRay

@MainActor
struct UninstallerFeatureControllerTests {
    @Test
    func loadInstalledAppsAndRemnantsUpdatesState() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let remnant = AppRemnant(
            url: URL(fileURLWithPath: "/Users/test/Library/Preferences/com.example.demo.plist"),
            sizeInBytes: 1024
        )
        let validation = makeValidation(app: app, removedPath: app.appURL.path, trashedPath: "/Users/test/.Trash/DemoApp.app")
        let controller = makeController(
            tempDir: tempDir,
            service: UninstallerControllerServiceStub(
                apps: [app],
                remnants: [remnant],
                validation: validation
            )
        )

        controller.loadInstalledApps()
        try await waitUntil("installed apps loaded") {
            !controller.state.isLoading && controller.state.installedApps.count == 1
        }

        controller.loadRemnants(for: app)
        try await waitUntil("remnants loaded") {
            !controller.state.isLoading && controller.state.remnants.count == 1
        }

        #expect(controller.state.uninstallReport == nil)
        #expect(controller.state.verifyReport == nil)
    }

    @Test
    func uninstallUpdatesVerifyStateAndSessions() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let remnant = AppRemnant(
            url: URL(fileURLWithPath: "/Users/test/Library/Preferences/com.example.demo.plist"),
            sizeInBytes: 1024
        )
        let validation = makeValidation(
            app: app,
            removedPath: remnant.url.path,
            trashedPath: "/Users/test/.Trash/com.example.demo.plist",
            type: .remnant
        )
        let service = UninstallerControllerServiceStub(
            apps: [app],
            remnants: [remnant],
            validation: validation
        )
        let controller = makeController(tempDir: tempDir, service: service)

        controller.loadRemnants(for: app)
        try await waitUntil("remnants loaded before uninstall") {
            !controller.state.isLoading && !controller.state.remnants.isEmpty
        }

        var callbackCount = 0
        controller.uninstall(app: app, isAppRunning: false) { _ in
            callbackCount += 1
        }

        try await waitUntil("uninstall completed") {
            !controller.state.isVerifyRunning && controller.state.uninstallReport != nil && controller.state.verifyReport != nil
        }

        #expect(callbackCount == 1)
        #expect(controller.state.sessions.count == 1)
        #expect(controller.state.verifyReport?.attemptedItems == 2)
    }

    @Test
    func runVerifyPassRefreshesRemainingAndVerifyReport() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let remnant = AppRemnant(
            url: URL(fileURLWithPath: "/Users/test/Library/LaunchAgents/com.example.demo.plist"),
            sizeInBytes: 2048
        )
        let validation = makeValidation(app: app, removedPath: app.appURL.path, trashedPath: "/Users/test/.Trash/DemoApp.app")
        let controller = makeController(
            tempDir: tempDir,
            service: UninstallerControllerServiceStub(
                apps: [app],
                remnants: [remnant],
                validation: validation
            )
        )

        controller.loadRemnants(for: app)
        try await waitUntil("remnants loaded before verify") {
            !controller.state.isLoading && controller.state.remnants.count == 1
        }

        controller.runVerifyPass(for: app, isAppRunning: true)

        try await waitUntil("verify pass completed") {
            !controller.state.isVerifyRunning && controller.state.verifyReport != nil
        }

        #expect(controller.state.remnants.count == 1)
        #expect(controller.state.verifyReport?.remainingCount == 1)
    }

    @Test
    func deepSweepRemainingRecordsAddsOrphanCandidates() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let remnantURL = tempDir
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("com.example.orphan", isDirectory: true)
            .appendingPathComponent("state.db")
        try FileManager.default.createDirectory(
            at: remnantURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("orphan".utf8).write(to: remnantURL)

        let app = InstalledApp(
            name: "DemoApp",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/DemoApp.app")
        )
        let validation = makeValidation(app: app, removedPath: app.appURL.path, trashedPath: "/Users/test/.Trash/DemoApp.app")
        let candidate = UninstallDeepSweepCandidate(
            appName: "Orphan",
            bundleID: "com.example.orphan",
            issues: [
                UninstallVerifyIssue(
                    url: remnantURL,
                    sizeInBytes: 6,
                    reason: "Detected by deep sweep as an orphaned artifact for a missing app bundle.",
                    risk: .medium
                )
            ]
        )

        let controller = makeController(
            tempDir: tempDir,
            service: UninstallerControllerServiceStub(
                apps: [app],
                remnants: [],
                validation: validation,
                deepSweepCandidates: [candidate]
            )
        )

        controller.loadInstalledApps()
        try await waitUntil("installed apps loaded for deep sweep") {
            !controller.state.isLoading && controller.state.installedApps.count == 1
        }

        controller.deepSweepRemainingRecords()
        try await waitUntil("deep sweep completed") {
            !controller.state.isLoading && !controller.state.remainingRecords.isEmpty
        }

        #expect(controller.state.remainingRecords.count == 1)
        #expect(controller.state.remainingRecords[0].bundleID == "com.example.orphan")
        #expect(controller.state.remainingRecords[0].remainingCount == 1)
    }

    private func makeController(
        tempDir: URL,
        service: UninstallerControllerServiceStub
    ) -> UninstallerFeatureController {
        let store = OperationalHistoryStore(directoryURL: tempDir)
        let sessionUseCase = UninstallSessionUseCase(
            historyStore: store,
            safeFileOperations: SafeFileOperationService()
        )
        let remainingUseCase = UninstallRemainingUseCase(historyStore: store)
        let observedAppsUseCase = UninstallObservedAppsUseCase(historyStore: store)
        let useCase = UninstallerUseCase(service: service)
        return UninstallerFeatureController(
            uninstallerUseCase: useCase,
            uninstallSessionUseCase: sessionUseCase,
            uninstallRemainingUseCase: remainingUseCase,
            uninstallObservedAppsUseCase: observedAppsUseCase,
            safeFileOperations: SafeFileOperationService()
        )
    }

    private func makeValidation(
        app: InstalledApp,
        removedPath: String,
        trashedPath: String,
        type: UninstallItemType = .appBundle
    ) -> UninstallValidationReport {
        UninstallValidationReport(
            appName: app.name,
            createdAt: Date(),
            results: [
                UninstallActionResult(
                    url: URL(fileURLWithPath: removedPath),
                    type: type,
                    status: .removed,
                    trashedPath: trashedPath,
                    details: nil
                )
            ]
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-uninstaller-controller-tests-\(UUID().uuidString)", isDirectory: true)
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

private actor UninstallerControllerServiceStub: UninstallerServicing {
    let apps: [InstalledApp]
    let remnants: [AppRemnant]
    let validation: UninstallValidationReport
    let deepSweepCandidates: [UninstallDeepSweepCandidate]

    init(
        apps: [InstalledApp],
        remnants: [AppRemnant],
        validation: UninstallValidationReport,
        deepSweepCandidates: [UninstallDeepSweepCandidate] = []
    ) {
        self.apps = apps
        self.remnants = remnants
        self.validation = validation
        self.deepSweepCandidates = deepSweepCandidates
    }

    func installedApps() async -> [InstalledApp] {
        apps
    }

    func findRemnants(for app: InstalledApp) async -> [AppRemnant] {
        remnants
    }

    func deepSweepOrphanRemnants(installedApps: [InstalledApp]) async -> [UninstallDeepSweepCandidate] {
        deepSweepCandidates
    }

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        validation
    }
}
