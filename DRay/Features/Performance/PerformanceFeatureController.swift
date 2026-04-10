import Foundation

@MainActor
final class PerformanceFeatureController: ObservableObject {
    @Published private(set) var state = PerformanceFeatureState()

    private let useCase: PerformanceUseCase
    private var context: FeatureContext?

    init(useCase: PerformanceUseCase) {
        self.useCase = useCase
        self.state.activeLoadReliefAdjustments = useCase.activeAdjustmentsCount
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func runDiagnostics() {
        guard !state.isScanRunning else { return }
        guard context?.allowProtectedModule("Performance Diagnostics") ?? false else { return }
        state.isScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let report = await useCase.runDiagnostics()
            await MainActor.run {
                state.report = report
                state.startupCleanupReport = nil
                state.isScanRunning = false
                context?.log(
                    category: "performance",
                    message: "Diagnostics done: startup entries \(report.startupEntries.count)"
                )
            }
        }
    }

    func runDiagnosticsSnapshot() async -> PerformanceReport {
        await useCase.runDiagnostics()
    }

    func applyDiagnosticsReport(_ report: PerformanceReport, clearStartupCleanup: Bool) {
        state.report = report
        if clearStartupCleanup {
            state.startupCleanupReport = nil
            state.quickActionDelta = nil
        }
        state.activeLoadReliefAdjustments = useCase.activeAdjustmentsCount
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) {
        guard !entries.isEmpty else { return }
        guard context?.allowModify(
            urls: entries.map(\.url),
            actionName: "Startup Cleanup",
            requiresFullDisk: true
        ) ?? false else { return }
        let before = startupTotals(from: state.report)
        state.isScanRunning = true

        Task { [weak self] in
            guard let self else { return }
            let report = await useCase.cleanupStartupEntries(entries)
            let refreshed = await useCase.runDiagnostics()
            let after = startupTotals(from: refreshed)

            await MainActor.run {
                state.startupCleanupReport = report
                state.report = refreshed
                state.isScanRunning = false
                state.quickActionDelta = QuickActionDeltaReport(
                    module: .performance,
                    actionTitle: "Startup Cleanup",
                    beforeItems: before.items,
                    beforeBytes: before.bytes,
                    afterItems: after.items,
                    afterBytes: after.bytes,
                    moved: report.moved,
                    failed: report.failed,
                    skippedProtected: report.skippedProtected
                )
                context?.log(
                    category: "performance",
                    message: "Startup cleanup moved \(report.moved), failed \(report.failed), skipped \(report.skippedProtected)"
                )
                context?.log(
                    category: "performance",
                    message: "Startup cleanup delta: items \(before.items)->\(after.items), bytes \(before.bytes)->\(after.bytes)"
                )
            }
        }
    }

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        let result = useCase.reduceCPULoad(consumers: consumers, limit: limit)
        state.activeLoadReliefAdjustments = useCase.activeAdjustmentsCount
        context?.log(
            category: "relief",
            message: "Load relief (cpu): adjusted \(result.adjusted.count), skipped \(result.skipped.count), failed \(result.failed.count)"
        )
        return result
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        let result = useCase.reduceMemoryLoad(consumers: consumers, limit: limit)
        state.activeLoadReliefAdjustments = useCase.activeAdjustmentsCount
        context?.log(
            category: "relief",
            message: "Load relief (memory): adjusted \(result.adjusted.count), skipped \(result.skipped.count), failed \(result.failed.count)"
        )
        return result
    }

    func restoreAdjustedPriorities(limit: Int = 5) -> LoadReliefResult {
        let result = useCase.restoreAdjustedPriorities(limit: limit)
        state.activeLoadReliefAdjustments = useCase.activeAdjustmentsCount
        context?.log(
            category: "relief",
            message: "Load relief restore: restored \(result.adjusted.count), skipped \(result.skipped.count), failed \(result.failed.count)"
        )
        return result
    }

    private func startupTotals(from report: PerformanceReport?) -> (items: Int, bytes: Int64) {
        guard let report else { return (0, 0) }
        return (report.startupEntries.count, report.startupTotalBytes)
    }
}
