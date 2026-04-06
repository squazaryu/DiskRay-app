import SwiftUI
import Combine

@MainActor
final class SmartCareViewModel: ObservableObject {
    private let root: RootViewModel
    private var rootChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var smartCare: SmartCareFeatureState {
        root.smartCare
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    var smartAnalyzerOptions: [SmartAnalyzerOption] {
        root.smartAnalyzerOptions
    }

    var unifiedScanSummary: UnifiedScanSummary? {
        root.unifiedScanSummary
    }

    var isUnifiedScanRunning: Bool {
        root.isUnifiedScanRunning
    }

    func binding<Value>(_ keyPath: WritableKeyPath<SmartCareFeatureState, Value>) -> Binding<Value> {
        Binding(
            get: { [weak self] in
                guard let self else { return SmartCareFeatureState()[keyPath: keyPath] }
                return self.root.smartCare[keyPath: keyPath]
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.root.smartCare[keyPath: keyPath] = newValue
            }
        )
    }

    func runSmartScan() {
        root.runSmartScan()
    }

    func runUnifiedScan() {
        root.runUnifiedScan()
    }

    func toggleSmartCategorySelection(_ id: String) {
        root.toggleSmartCategorySelection(id)
    }

    func cleanSelectedSmartCategories() {
        root.cleanSelectedSmartCategories()
    }

    func cleanRecommendedSmartCategories() {
        root.cleanRecommendedSmartCategories()
    }

    func cleanSmartItems(_ items: [CleanupItem]) {
        root.cleanSmartItems(items)
    }

    func selectRecommendedSmartCategories() {
        root.selectRecommendedSmartCategories()
    }

    func applySmartProfile(_ profile: SmartCleanProfile) {
        root.applySmartProfile(profile)
    }

    func addSmartExclusion(_ path: String) {
        root.addSmartExclusion(path)
    }

    func removeSmartExclusion(_ path: String) {
        root.removeSmartExclusion(path)
    }

    func toggleSmartExclusion(_ path: String) {
        root.toggleSmartExclusion(path)
    }

    func toggleSmartAnalyzerExclusion(_ analyzerKey: String) {
        root.toggleSmartAnalyzerExclusion(analyzerKey)
    }
}
