import SwiftUI
import Combine

@MainActor
final class UninstallerViewModel: ObservableObject {
    private let root: RootViewModel
    private let uninstallerController: UninstallerFeatureController
    private var rootChangeCancellable: AnyCancellable?
    private var uninstallerChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.uninstallerController = root.uninstaller
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.uninstallerChangeCancellable = uninstallerController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var state: UninstallerFeatureState {
        uninstallerController.state
    }

    func loadInstalledApps() {
        uninstallerController.loadInstalledApps()
    }

    func loadRemnants(for app: InstalledApp) {
        uninstallerController.loadRemnants(for: app)
    }

    func uninstallPreview(for app: InstalledApp) -> [UninstallPreviewItem] {
        uninstallerController.uninstallPreview(for: app)
    }

    func uninstall(
        app: InstalledApp,
        selectedItems: [UninstallPreviewItem]? = nil,
        isAppRunning: Bool,
        onFinished: @escaping (_ result: UninstallExecutionResult) -> Void = { _ in }
    ) {
        uninstallerController.uninstall(
            app: app,
            selectedItems: selectedItems,
            isAppRunning: isAppRunning,
            onFinished: onFinished
        )
    }

    @discardableResult
    func restoreFromSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> UninstallSessionRestoreResult {
        uninstallerController.restoreFromSession(session, item: item)
    }

    func runVerifyPass(for app: InstalledApp, isAppRunning: Bool) {
        uninstallerController.runVerifyPass(for: app, isAppRunning: isAppRunning)
    }

    func openSection(_ section: AppSection) {
        root.openSection(section)
    }
}
