import Foundation
import Combine

@MainActor
final class ClutterViewModel: ObservableObject {
    private let root: RootViewModel
    private let duplicatesController: DuplicatesFeatureController
    private var rootChangeCancellable: AnyCancellable?
    private var duplicatesChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.duplicatesController = root.duplicatesController
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.duplicatesChangeCancellable = duplicatesController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var duplicateGroups: [DuplicateGroup] {
        duplicatesController.state.groups
    }

    var isDuplicateScanRunning: Bool {
        duplicatesController.state.isScanRunning
    }

    var duplicateScanProgress: DuplicateScanProgress {
        duplicatesController.state.progress
    }

    var duplicateMinSizeMB: Double {
        get { duplicatesController.state.minSizeMB }
        set { duplicatesController.updateMinSizeMB(newValue) }
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    var confirmBeforeDestructiveActions: Bool {
        root.confirmBeforeDestructiveActions
    }

    func scanDuplicatesInSelectedTarget() {
        duplicatesController.scanDuplicatesInSelectedTarget(root.selectedTarget.url)
    }

    func scanDuplicatesInHome() {
        duplicatesController.scanDuplicatesInHome()
    }

    func cancelDuplicateScan() {
        duplicatesController.cancelDuplicateScan()
    }

    func clearDuplicateResults() {
        duplicatesController.clearDuplicateResults()
    }

    func moveDuplicatePathsToTrash(_ paths: [String]) -> TrashOperationResult {
        duplicatesController.moveDuplicatePathsToTrash(
            paths,
            onMovedItems: { [weak self] moved in
                self?.root.recovery.recordMovedItems(moved)
            },
            onSuccessfulCleanup: { [weak self] in
                guard let self, self.root.lastScannedTarget != nil else { return }
                self.root.scheduleRescanAfterMutation()
            }
        )
    }

    func exportOperationLogReport() -> URL? {
        root.exportOperationLogReport()
    }

    func isPathProtectedForManualCleanup(_ path: String) -> Bool {
        root.isPathProtectedForManualCleanup(path)
    }

    func trashResultMessage(_ result: TrashOperationResult) -> String {
        root.trashResultMessage(result)
    }
}
