import SwiftUI
import Combine

@MainActor
final class PerformanceViewModel: ObservableObject {
    private let root: RootViewModel
    private let performanceController: PerformanceFeatureController
    private var rootChangeCancellable: AnyCancellable?
    private var performanceChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.performanceController = root.performanceController
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.performanceChangeCancellable = performanceController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var performance: PerformanceFeatureState {
        performanceController.state
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    var confirmBeforeStartupCleanup: Bool {
        root.confirmBeforeStartupCleanup
    }

    var performanceQuickActionDelta: QuickActionDeltaReport? {
        root.performanceQuickActionDelta
    }

    func runPerformanceScan() {
        performanceController.runDiagnostics()
    }

    func loadBatteryEnergyReport(force: Bool = false) {
        performanceController.loadBatteryEnergyReport(force: force)
    }

    func runNetworkSpeedTest() {
        performanceController.runNetworkSpeedTest()
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) {
        performanceController.cleanupStartupEntries(entries)
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
        root.smartCareController.runSmartScan()
    }
}
