import Foundation

protocol PerformanceServicing: Sendable {
    func buildReport() async -> PerformanceReport
    func cleanupStartupEntries(_ entries: [StartupEntry]) async -> StartupCleanupReport
}

@MainActor
protocol ProcessPriorityServicing: AnyObject {
    var activeAdjustmentsCount: Int { get }
    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult
    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult
    func restoreAdjustedPriorities(limit: Int) -> LoadReliefResult
}

@MainActor
struct PerformanceUseCase {
    let performanceService: any PerformanceServicing
    let processPriorityService: any ProcessPriorityServicing

    var activeAdjustmentsCount: Int {
        processPriorityService.activeAdjustmentsCount
    }

    func runDiagnostics() async -> PerformanceReport {
        await performanceService.buildReport()
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) async -> StartupCleanupReport {
        await performanceService.cleanupStartupEntries(entries)
    }

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        processPriorityService.reduceCPULoad(consumers: consumers, limit: limit)
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        processPriorityService.reduceMemoryLoad(consumers: consumers, limit: limit)
    }

    func restoreAdjustedPriorities(limit: Int) -> LoadReliefResult {
        processPriorityService.restoreAdjustedPriorities(limit: limit)
    }
}
