import Foundation

protocol UninstallerServicing: Sendable {
    func installedApps() async -> [InstalledApp]
    func findRemnants(for app: InstalledApp) async -> [AppRemnant]
    func findStartupReferences(for app: InstalledApp) async -> [UninstallStartupReference]
    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport
}

extension UninstallerServicing {
    func findStartupReferences(for app: InstalledApp) async -> [UninstallStartupReference] { [] }
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

    func findRemnants(for app: InstalledApp) async -> [AppRemnant] {
        await service.findRemnants(for: app)
    }

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        await service.uninstall(app: app, previewItems: previewItems)
    }

    func uninstallAndVerify(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        isProtectedPath: (String) -> Bool,
        isAppRunning: Bool
    ) async -> UninstallExecutionResult {
        let validation = await service.uninstall(app: app, previewItems: previewItems)
        let remaining = await service.findRemnants(for: app)
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
        isProtectedPath: (String) -> Bool,
        isAppRunning: Bool
    ) async -> UninstallVerifyPassResult {
        let remaining = await service.findRemnants(for: app)
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

    func uninstallPreview(app: InstalledApp, remnants: [AppRemnant]) -> [UninstallPreviewItem] {
        planner.uninstallPreview(app: app, remnants: remnants)
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
