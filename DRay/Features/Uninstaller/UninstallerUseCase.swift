import Foundation

protocol UninstallerServicing: Sendable {
    func installedApps() async -> [InstalledApp]
    func findRemnants(for app: InstalledApp, mode: UninstallMode) async -> [AppRemnant]
    func findStartupReferences(for app: InstalledApp) async -> [UninstallStartupReference]
    func deepSweepOrphanRemnants(installedApps: [InstalledApp]) async -> [UninstallDeepSweepCandidate]
    func uninstall(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        allowForceRemove: Bool
    ) async -> UninstallValidationReport
}

extension UninstallerServicing {
    func findStartupReferences(for app: InstalledApp) async -> [UninstallStartupReference] { [] }
    func deepSweepOrphanRemnants(installedApps: [InstalledApp]) async -> [UninstallDeepSweepCandidate] { [] }
    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        await uninstall(app: app, previewItems: previewItems, allowForceRemove: false)
    }
}

struct UninstallExecutionResult: Sendable {
    let validation: UninstallValidationReport
    let verifyReport: UninstallVerifyReport
    let remainingRemnants: [AppRemnant]
}

struct UninstallVerifyPassResult: Sendable {
    let verifyReport: UninstallVerifyReport
    let remainingRemnants: [AppRemnant]
}

@MainActor
struct UninstallerUseCase {
    let service: any UninstallerServicing
    private let planner = UninstallPlanningUseCase()

    func installedApps() async -> [InstalledApp] {
        await service.installedApps()
    }

    func findRemnants(for app: InstalledApp, mode: UninstallMode) async -> [AppRemnant] {
        await service.findRemnants(for: app, mode: mode)
    }

    func deepSweepOrphanRemnants(installedApps: [InstalledApp]) async -> [UninstallDeepSweepCandidate] {
        await service.deepSweepOrphanRemnants(installedApps: installedApps)
    }

    func uninstall(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        allowForceRemove: Bool = false
    ) async -> UninstallValidationReport {
        await service.uninstall(app: app, previewItems: previewItems, allowForceRemove: allowForceRemove)
    }

    func uninstallAndVerify(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        mode: UninstallMode,
        allowForceRemove: Bool,
        isProtectedPath: (String) -> Bool,
        isAppRunning: Bool
    ) async -> UninstallExecutionResult {
        let validation = await service.uninstall(
            app: app,
            previewItems: previewItems,
            allowForceRemove: allowForceRemove
        )
        let remaining = await service.findRemnants(for: app, mode: mode)
        let startupReferences = await service.findStartupReferences(for: app)
        let verifyReport = planner.buildVerifyReport(
            app: app,
            previewItems: previewItems,
            validation: validation,
            remaining: remaining,
            startupReferences: startupReferences,
            isProtectedPath: isProtectedPath,
            isAppRunning: isAppRunning
        )
        return UninstallExecutionResult(
            validation: validation,
            verifyReport: verifyReport,
            remainingRemnants: remaining
        )
    }

    func runVerifyPass(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        validation: UninstallValidationReport?,
        mode: UninstallMode,
        isProtectedPath: (String) -> Bool,
        isAppRunning: Bool
    ) async -> UninstallVerifyPassResult {
        let remaining = await service.findRemnants(for: app, mode: mode)
        let startupReferences = await service.findStartupReferences(for: app)
        let verifyReport = planner.buildVerifyReport(
            app: app,
            previewItems: previewItems,
            validation: validation,
            remaining: remaining,
            startupReferences: startupReferences,
            isProtectedPath: isProtectedPath,
            isAppRunning: isAppRunning
        )
        return UninstallVerifyPassResult(
            verifyReport: verifyReport,
            remainingRemnants: remaining
        )
    }

    func repairRisk(for remnant: AppRemnant) -> UninstallRiskLevel {
        planner.repairRisk(for: remnant)
    }

    func uninstallPreview(app: InstalledApp, remnants: [AppRemnant], mode: UninstallMode) -> [UninstallPreviewItem] {
        planner.uninstallPreview(app: app, remnants: remnants, mode: mode)
    }

    func buildVerifyReport(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        validation: UninstallValidationReport?,
        remaining: [AppRemnant],
        startupReferences: [UninstallStartupReference] = [],
        isProtectedPath: (String) -> Bool,
        isAppRunning: Bool
    ) -> UninstallVerifyReport {
        planner.buildVerifyReport(
            app: app,
            previewItems: previewItems,
            validation: validation,
            remaining: remaining,
            startupReferences: startupReferences,
            isProtectedPath: isProtectedPath,
            isAppRunning: isAppRunning
        )
    }
}
