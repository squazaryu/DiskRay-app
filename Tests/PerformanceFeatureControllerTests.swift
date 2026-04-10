import Foundation
import Testing
@testable import DRay

@MainActor
struct PerformanceFeatureControllerTests {
    @Test
    func runDiagnosticsBlockedByPermissionGate() async {
        let service = PerformanceControllerServiceStub(reports: [makeReport(startupCount: 1)])
        let controller = makeController(service: service)

        var blockedMessage: String?
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .blocked("blocked") },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { blockedMessage = $0 },
                addOperationLog: { _, _ in }
            )
        )

        controller.runDiagnostics()

        #expect(blockedMessage == "blocked")
        #expect(controller.state.isScanRunning == false)
        #expect(controller.state.report == nil)
        #expect(await service.buildReportCallCount() == 0)
    }

    @Test
    func runDiagnosticsUpdatesState() async throws {
        let service = PerformanceControllerServiceStub(reports: [makeReport(startupCount: 2)])
        let controller = makeController(service: service)
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, _ in }
            )
        )

        controller.runDiagnostics()

        try await waitUntil("diagnostics finished") {
            !controller.state.isScanRunning && controller.state.report != nil
        }

        #expect(controller.state.report?.startupEntries.count == 2)
        #expect(controller.state.startupCleanupReport == nil)
        #expect(await service.buildReportCallCount() == 1)
    }

    @Test
    func cleanupStartupEntriesBuildsQuickActionDelta() async throws {
        let initial = makeReport(startupEntries: [
            StartupEntry(
                name: "a.plist",
                url: URL(fileURLWithPath: "/tmp/a.plist"),
                source: "Test",
                sizeInBytes: 120
            ),
            StartupEntry(
                name: "b.plist",
                url: URL(fileURLWithPath: "/tmp/b.plist"),
                source: "Test",
                sizeInBytes: 80
            )
        ])
        let refreshed = makeReport(startupEntries: [
            StartupEntry(
                name: "a.plist",
                url: URL(fileURLWithPath: "/tmp/a.plist"),
                source: "Test",
                sizeInBytes: 120
            )
        ])
        let service = PerformanceControllerServiceStub(
            reports: [refreshed],
            cleanupReport: StartupCleanupReport(moved: 1, failed: 0, skippedProtected: 0)
        )
        let controller = makeController(service: service)

        var canModifyCalled = false
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { urls, _, requiresFullDisk in
                    canModifyCalled = true
                    #expect(urls.count == 1)
                    #expect(requiresFullDisk == true)
                    return .allowed
                },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, _ in }
            )
        )

        controller.applyDiagnosticsReport(initial, clearStartupCleanup: false)
        controller.cleanupStartupEntries([initial.startupEntries[0]])

        try await waitUntil("startup cleanup finished") {
            !controller.state.isScanRunning && controller.state.quickActionDelta != nil
        }

        let delta = try #require(controller.state.quickActionDelta)
        #expect(canModifyCalled == true)
        #expect(controller.state.startupCleanupReport?.moved == 1)
        #expect(delta.module == .performance)
        #expect(delta.actionTitle == "Startup Cleanup")
        #expect(delta.beforeItems == 2)
        #expect(delta.afterItems == 1)
        #expect(delta.beforeBytes == 200)
        #expect(delta.afterBytes == 120)
        #expect(await service.cleanupCallCount() == 1)
        #expect(await service.buildReportCallCount() == 1)
    }

    @Test
    func loadReliefActionsUpdateActiveAdjustments() {
        let service = PerformanceControllerServiceStub(reports: [])
        let priorities = ProcessPriorityControllerServiceStub()
        priorities.activeAdjustmentsCount = 1
        priorities.cpuResult = LoadReliefResult(adjusted: ["a"], skipped: [], failed: [])
        priorities.memoryResult = LoadReliefResult(adjusted: ["b"], skipped: [], failed: [])
        priorities.restoreResult = LoadReliefResult(adjusted: ["a", "b"], skipped: [], failed: [])

        let useCase = PerformanceUseCase(
            performanceService: service,
            processPriorityService: priorities
        )
        let controller = PerformanceFeatureController(useCase: useCase)
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, _ in }
            )
        )

        let consumers = [ProcessConsumer(pid: 1, name: "proc", cpuPercent: 90, memoryMB: 512, batteryImpactScore: 20)]

        let cpu = controller.reduceCPULoad(consumers: consumers, limit: 2)
        #expect(cpu.adjusted == ["a"])
        #expect(controller.state.activeLoadReliefAdjustments == 1)

        priorities.activeAdjustmentsCount = 2
        let memory = controller.reduceMemoryLoad(consumers: consumers, limit: 3)
        #expect(memory.adjusted == ["b"])
        #expect(controller.state.activeLoadReliefAdjustments == 2)

        priorities.activeAdjustmentsCount = 0
        let restore = controller.restoreAdjustedPriorities(limit: 5)
        #expect(restore.adjusted == ["a", "b"])
        #expect(controller.state.activeLoadReliefAdjustments == 0)
    }

    private func makeController(
        service: PerformanceControllerServiceStub,
        priorityService: ProcessPriorityControllerServiceStub = ProcessPriorityControllerServiceStub()
    ) -> PerformanceFeatureController {
        let useCase = PerformanceUseCase(
            performanceService: service,
            processPriorityService: priorityService
        )
        return PerformanceFeatureController(useCase: useCase)
    }

    private func makeReport(startupCount: Int) -> PerformanceReport {
        makeReport(startupEntries: (0..<startupCount).map { idx in
            StartupEntry(
                name: "entry-\(idx).plist",
                url: URL(fileURLWithPath: "/tmp/entry-\(idx).plist"),
                source: "Test",
                sizeInBytes: Int64(idx + 1) * 100
            )
        })
    }

    private func makeReport(startupEntries: [StartupEntry]) -> PerformanceReport {
        PerformanceReport(
            generatedAt: Date(),
            startupEntries: startupEntries,
            diskFreeBytes: 500,
            diskTotalBytes: 1_000,
            recommendations: []
        )
    }

    private func waitUntil(
        _ description: String,
        timeoutSeconds: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) async throws {
        let timeout = Date().addingTimeInterval(timeoutSeconds)
        while !condition(), Date() < timeout {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(condition(), "\(description) timed out")
    }
}

private actor PerformanceControllerServiceStub: PerformanceServicing {
    private var queuedReports: [PerformanceReport]
    private let cleanupResult: StartupCleanupReport
    private var buildCalls = 0
    private var cleanupCalls = 0

    init(
        reports: [PerformanceReport],
        cleanupReport: StartupCleanupReport = StartupCleanupReport(moved: 0, failed: 0, skippedProtected: 0)
    ) {
        self.queuedReports = reports
        self.cleanupResult = cleanupReport
    }

    func buildReport() async -> PerformanceReport {
        buildCalls += 1
        if !queuedReports.isEmpty {
            return queuedReports.removeFirst()
        }
        return PerformanceReport(
            generatedAt: Date(),
            startupEntries: [],
            diskFreeBytes: nil,
            diskTotalBytes: nil,
            recommendations: []
        )
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) async -> StartupCleanupReport {
        cleanupCalls += 1
        return cleanupResult
    }

    func buildReportCallCount() -> Int { buildCalls }
    func cleanupCallCount() -> Int { cleanupCalls }
}

@MainActor
private final class ProcessPriorityControllerServiceStub: ProcessPriorityServicing {
    var activeAdjustmentsCount = 0
    var cpuResult = LoadReliefResult(adjusted: [], skipped: [], failed: [])
    var memoryResult = LoadReliefResult(adjusted: [], skipped: [], failed: [])
    var restoreResult = LoadReliefResult(adjusted: [], skipped: [], failed: [])

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        cpuResult
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        memoryResult
    }

    func restoreAdjustedPriorities(limit: Int) -> LoadReliefResult {
        restoreResult
    }
}
