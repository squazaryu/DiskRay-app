import SwiftUI
import Combine

@MainActor
final class PrivacyViewModel: ObservableObject {
    private let root: RootViewModel
    private let privacyController: PrivacyFeatureController
    private var rootChangeCancellable: AnyCancellable?
    private var privacyChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.privacyController = root.privacy
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.privacyChangeCancellable = privacyController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var state: PrivacyFeatureState {
        privacyController.state
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    func runScan() {
        privacyController.runScan()
    }

    func toggleCategory(_ id: String) {
        privacyController.toggleCategory(id)
    }

    func clearSelection() {
        privacyController.clearSelection()
    }

    func selectRecommended(includeMediumRisk: Bool) {
        privacyController.selectRecommended(includeMediumRisk: includeMediumRisk)
    }

    func cleanRecommended(includeMediumRisk: Bool) {
        privacyController.cleanRecommended(includeMediumRisk: includeMediumRisk)
    }

    func cleanSelected() {
        privacyController.cleanSelected()
    }
}
