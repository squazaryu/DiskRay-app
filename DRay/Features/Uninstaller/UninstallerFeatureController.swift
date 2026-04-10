import Foundation

@MainActor
final class UninstallerFeatureController: ObservableObject {
    @Published private(set) var state = UninstallerFeatureState()

    private let uninstallerUseCase: UninstallerUseCase
    private let uninstallSessionUseCase: UninstallSessionUseCase
    private let safeFileOperations: SafeFileOperationService
    private var context: FeatureContext?

    init(
        uninstallerUseCase: UninstallerUseCase,
        uninstallSessionUseCase: UninstallSessionUseCase,
        safeFileOperations: SafeFileOperationService
    ) {
        self.uninstallerUseCase = uninstallerUseCase
        self.uninstallSessionUseCase = uninstallSessionUseCase
        self.safeFileOperations = safeFileOperations
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func loadSessions() {
        state.sessions = uninstallSessionUseCase.load(kind: .uninstall)
    }

    func loadInstalledApps() {
        state.isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let apps = await uninstallerUseCase.installedApps()
            await MainActor.run {
                state.installedApps = apps
                state.isLoading = false
            }
        }
    }

    func loadRemnants(for app: InstalledApp) {
        state.isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let remnants = await uninstallerUseCase.findRemnants(for: app)
            await MainActor.run {
                state.remnants = remnants
                state.uninstallReport = nil
                state.verifyReport = nil
                state.isLoading = false
            }
        }
    }

    func uninstallPreview(for app: InstalledApp) -> [UninstallPreviewItem] {
        uninstallerUseCase.uninstallPreview(app: app, remnants: state.remnants)
    }

    func uninstall(
        app: InstalledApp,
        selectedItems: [UninstallPreviewItem]? = nil,
        isAppRunning: Bool,
        onFinished: @escaping (_ result: UninstallExecutionResult) -> Void = { _ in }
    ) {
        guard context?.allowProtectedModule("Uninstall") ?? true else { return }
        let preview = uninstallPreview(for: app)
        let items = selectedItems ?? preview
        context?.log(
            category: "uninstaller",
            message: "Uninstall started for \(app.name), items \(items.count)"
        )

        state.isVerifyRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerUseCase.uninstallAndVerify(
                app: app,
                previewItems: items,
                isProtectedPath: { path in
                    safeFileOperations.isProtectedPath(path)
                },
                isAppRunning: isAppRunning
            )
            await MainActor.run {
                state.uninstallReport = result.validation
                state.verifyReport = result.verifyReport
                state.isVerifyRunning = false
                state.sessions = uninstallSessionUseCase.appendSession(
                    from: result.validation,
                    existingSessions: state.sessions,
                    kind: .uninstall
                )
                state.remnants = result.remainingRemnants
                context?.log(
                    category: "uninstaller",
                    message: "Uninstall \(app.name): removed \(result.validation.removedCount), skipped \(result.validation.skippedCount), failed \(result.validation.failedCount)"
                )
                onFinished(result)
            }
        }
    }

    func runVerifyPass(
        for app: InstalledApp,
        isAppRunning: Bool
    ) {
        guard context?.allowProtectedModule("Uninstall Verify") ?? true else { return }
        let validation = state.uninstallReport
        let preview = uninstallPreview(for: app)
        state.isVerifyRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerUseCase.runVerifyPass(
                app: app,
                previewItems: preview,
                validation: validation,
                isProtectedPath: { path in
                    safeFileOperations.isProtectedPath(path)
                },
                isAppRunning: isAppRunning
            )
            await MainActor.run {
                state.remnants = result.remainingRemnants
                state.verifyReport = result.verifyReport
                state.isVerifyRunning = false
                context?.log(
                    category: "uninstaller",
                    message: "Verify pass \(app.name): remaining \(result.verifyReport.remainingCount), startup refs \(result.verifyReport.startupReferenceCount)"
                )
            }
        }
    }

    @discardableResult
    func restoreFromSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> UninstallSessionRestoreResult {
        let result = uninstallSessionUseCase.restore(
            from: session,
            item: item,
            sessions: state.sessions,
            kind: .uninstall
        )
        if result.restoredCount > 0 {
            state.sessions = result.sessions
            context?.log(
                category: "uninstaller",
                message: "Rollback restored \(result.restoredCount) item(s) for \(session.appName)"
            )
        }
        if !result.failures.isEmpty {
            context?.log(
                category: "uninstaller",
                message: "Rollback failures for \(session.appName): \(result.failures.count)"
            )
        }
        return result
    }
}
