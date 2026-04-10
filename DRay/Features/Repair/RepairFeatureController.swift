import Foundation

@MainActor
final class RepairFeatureController: ObservableObject {
    @Published private(set) var state = RepairFeatureState()

    private let uninstallerUseCase: UninstallerUseCase
    private let uninstallSessionUseCase: UninstallSessionUseCase
    private var context: FeatureContext?

    init(
        uninstallerUseCase: UninstallerUseCase,
        uninstallSessionUseCase: UninstallSessionUseCase
    ) {
        self.uninstallerUseCase = uninstallerUseCase
        self.uninstallSessionUseCase = uninstallSessionUseCase
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func loadSessions() {
        state.sessions = uninstallSessionUseCase.load(kind: .repair)
    }

    func loadArtifacts(for app: InstalledApp) {
        state.isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let artifacts = await uninstallerUseCase.findRemnants(for: app)
            await MainActor.run {
                state.artifacts = artifacts
                state.report = nil
                state.isLoading = false
            }
        }
    }

    func runRepair(
        app: InstalledApp,
        artifacts: [AppRemnant],
        onFinished: @escaping (_ report: UninstallValidationReport) -> Void = { _ in }
    ) {
        guard !artifacts.isEmpty else { return }
        guard context?.allowProtectedModule("App Repair") ?? true else { return }
        guard context?.allowModify(
            urls: artifacts.map(\.url),
            actionName: "App Repair",
            requiresFullDisk: true
        ) ?? true else { return }
        context?.log(
            category: "repair",
            message: "Repair started for \(app.name), artifacts \(artifacts.count)"
        )
        state.isLoading = true
        let previewItems = artifacts.map {
            UninstallPreviewItem(
                url: $0.url,
                type: .remnant,
                sizeInBytes: $0.sizeInBytes,
                risk: .low,
                reason: "App repair artifact cleanup"
            )
        }

        Task { [weak self] in
            guard let self else { return }
            let report = await uninstallerUseCase.uninstall(app: app, previewItems: previewItems)
            await MainActor.run {
                state.report = report
                state.isLoading = false
                state.sessions = uninstallSessionUseCase.appendSession(
                    from: report,
                    existingSessions: state.sessions,
                    kind: .repair
                )
                context?.log(
                    category: "repair",
                    message: "Repair \(app.name): removed \(report.removedCount), skipped \(report.skippedCount), failed \(report.failedCount)"
                )
                onFinished(report)
            }
        }
    }

    func recommendedArtifacts(for strategy: AppRepairStrategy) -> [AppRemnant] {
        switch strategy {
        case .safeReset:
            return state.artifacts.filter { repairRisk(for: $0) == .low }
        case .deepReset:
            return state.artifacts
        }
    }

    func repairRisk(for artifact: AppRemnant) -> UninstallRiskLevel {
        uninstallerUseCase.repairRisk(for: artifact)
    }

    @discardableResult
    func restoreFromSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> UninstallSessionRestoreResult {
        let result = uninstallSessionUseCase.restore(
            from: session,
            item: item,
            sessions: state.sessions,
            kind: .repair
        )
        if result.restoredCount > 0 {
            state.sessions = result.sessions
            context?.log(
                category: "repair",
                message: "Repair rollback restored \(result.restoredCount) item(s) for \(session.appName)"
            )
        }
        if !result.failures.isEmpty {
            context?.log(
                category: "repair",
                message: "Repair rollback failures for \(session.appName): \(result.failures.count)"
            )
        }
        return result
    }
}
