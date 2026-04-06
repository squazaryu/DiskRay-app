import SwiftUI
import Combine

@MainActor
final class PerformanceViewModel: ObservableObject {
    private let root: RootViewModel
    private var rootChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var performance: PerformanceFeatureState {
        root.performance
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    var performanceQuickActionDelta: QuickActionDeltaReport? {
        root.performanceQuickActionDelta
    }

    func runPerformanceScan() {
        root.runPerformanceScan()
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) {
        root.cleanupStartupEntries(entries)
    }

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        root.reduceCPULoad(consumers: consumers, limit: limit)
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        root.reduceMemoryLoad(consumers: consumers, limit: limit)
    }

    func restoreAdjustedProcessPriorities(limit: Int = 5) -> LoadReliefResult {
        root.restoreAdjustedProcessPriorities(limit: limit)
    }

    func exportOperationLogReport() -> URL? {
        root.exportOperationLogReport()
    }

    func revealCrashTelemetry() {
        root.revealCrashTelemetry()
    }

    func openSection(_ section: AppSection) {
        root.openSection(section)
    }

    func runSmartScan() {
        root.runSmartScan()
    }
}
