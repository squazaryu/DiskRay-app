import Foundation

enum AppLaunchAction: String {
    case runUnifiedScan = "run-unified-scan"
    case runPerformanceScan = "run-performance-scan"
    case scanDuplicatesHome = "scan-duplicates-home"
    case runSpaceLensScan = "run-space-lens-scan"
}

enum AppIPC {
    static let openSectionName = Notification.Name("com.squazaryu.dray.open-section")
    static let quitCompletelyName = Notification.Name("com.squazaryu.dray.quit-completely")
    static let sectionKey = "section"
    static let actionKey = "action"
}

@MainActor
final class AppIPCReceiver {
    static let shared = AppIPCReceiver()

    private var model: RootViewModel?
    private var openSectionObserver: NSObjectProtocol?
    private var quitObserver: NSObjectProtocol?

    private init() {
        let center = DistributedNotificationCenter.default()
        openSectionObserver = center.addObserver(
            forName: AppIPC.openSectionName,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let sectionRaw = note.userInfo?[AppIPC.sectionKey] as? String
            let actionRaw = note.userInfo?[AppIPC.actionKey] as? String
            Task { @MainActor in
                self?.handleOpenSection(sectionRaw: sectionRaw, actionRaw: actionRaw)
            }
        }

        quitObserver = center.addObserver(
            forName: AppIPC.quitCompletelyName,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppTerminationCoordinator.shared.terminateCompletely()
            }
        }
    }

    func configure(model: RootViewModel) {
        self.model = model
    }

    private func handleOpenSection(sectionRaw: String?, actionRaw: String?) {
        guard let model else { return }

        if let sectionRaw,
           let section = AppSection(rawValue: sectionRaw) {
            model.selectedSection = section
        }

        if let actionRaw,
           let action = AppLaunchAction(rawValue: actionRaw) {
            execute(action: action, model: model)
        }

        AppTerminationCoordinator.shared.showMainWindow()
    }

    func execute(action: AppLaunchAction, model: RootViewModel) {
        switch action {
        case .runUnifiedScan:
            model.runUnifiedScan()
        case .runPerformanceScan:
            model.runPerformanceScan()
        case .scanDuplicatesHome:
            model.duplicatesController.scanDuplicatesInHome()
        case .runSpaceLensScan:
            model.scanSelected()
        }
    }
}
