import SwiftUI
import Combine

@MainActor
final class SmartCareViewModel: ObservableObject {
    private let root: RootViewModel
    private let smartCareController: SmartCareFeatureController
    private var rootChangeCancellable: AnyCancellable?
    private var smartCareChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.smartCareController = root.smartCareController
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.smartCareChangeCancellable = smartCareController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var smartCare: SmartCareFeatureState {
        smartCareController.state
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    var smartAnalyzerOptions: [SmartAnalyzerOption] {
        smartCareController.smartAnalyzerOptions
    }

    var unifiedScanSummary: UnifiedScanSummary? {
        root.unifiedScanSummary
    }

    var isUnifiedScanRunning: Bool {
        root.isUnifiedScanRunning
    }

    var minCleanSizeMBBinding: Binding<Double> {
        Binding(
            get: { [weak self] in
                self?.smartCareController.state.minCleanSizeMB ?? 1
            },
            set: { [weak self] newValue in
                self?.smartCareController.updateMinCleanSizeMB(newValue)
            }
        )
    }

    func runSmartScan() {
        smartCareController.runSmartScan()
    }

    func runUnifiedScan() {
        root.runUnifiedScan()
    }

    func toggleSmartCategorySelection(_ id: String) {
        smartCareController.toggleSmartCategorySelection(id)
    }

    func cleanSelectedSmartCategories() {
        smartCareController.cleanSelectedSmartCategories()
    }

    func cleanRecommendedSmartCategories() {
        smartCareController.cleanRecommendedSmartCategories()
    }

    func cleanSmartItems(_ items: [CleanupItem]) {
        smartCareController.cleanSmartItems(items)
    }

    func selectRecommendedSmartCategories() {
        smartCareController.selectRecommendedSmartCategories()
    }

    func applySmartProfile(_ profile: SmartCleanProfile) {
        smartCareController.applySmartProfile(profile)
    }

    func addSmartExclusion(_ path: String) {
        smartCareController.addSmartExclusion(path)
    }

    func removeSmartExclusion(_ path: String) {
        smartCareController.removeSmartExclusion(path)
    }

    func toggleSmartExclusion(_ path: String) {
        smartCareController.toggleSmartExclusion(path)
    }

    func toggleSmartAnalyzerExclusion(_ analyzerKey: String) {
        smartCareController.toggleSmartAnalyzerExclusion(analyzerKey)
    }
}
