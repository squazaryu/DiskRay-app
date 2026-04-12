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
        let battery = BatteryEnergyControllerServiceStub(
            reports: [makeBatteryEnergyReport(consumers: 2)]
        )
        let controller = makeController(service: service, batteryService: battery)
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
        #expect(controller.state.batteryEnergyReport?.consumers.count == 2)
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
            processPriorityService: priorities,
            batteryEnergyService: BatteryEnergyControllerServiceStub(reports: [makeBatteryEnergyReport(consumers: 0)])
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
        priorityService: ProcessPriorityControllerServiceStub = ProcessPriorityControllerServiceStub(),
        batteryService: BatteryEnergyControllerServiceStub = BatteryEnergyControllerServiceStub(reports: [])
    ) -> PerformanceFeatureController {
        let useCase = PerformanceUseCase(
            performanceService: service,
            processPriorityService: priorityService,
            batteryEnergyService: batteryService
        )
        return PerformanceFeatureController(useCase: useCase)
    }

    @Test
    func loadBatteryEnergyReportUpdatesState() async throws {
        let service = PerformanceControllerServiceStub(reports: [])
        let battery = BatteryEnergyControllerServiceStub(
            reports: [makeBatteryEnergyReport(consumers: 3)]
        )
        let useCase = PerformanceUseCase(
            performanceService: service,
            processPriorityService: ProcessPriorityControllerServiceStub(),
            batteryEnergyService: battery
        )
        let controller = PerformanceFeatureController(useCase: useCase)

        controller.loadBatteryEnergyReport(force: true)

        try await waitUntil("battery report finished") {
            !controller.state.isBatteryEnergyLoading && controller.state.batteryEnergyReport != nil
        }

        #expect(controller.state.batteryEnergyReport?.consumers.count == 3)
        #expect(await battery.callCount() == 1)
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

    private func makeBatteryEnergyReport(consumers: Int) -> BatteryEnergyReport {
        var rows: [EnergyConsumerSnapshot] = []
        rows.reserveCapacity(consumers)
        for idx in 0..<consumers {
            let index = idx + 1
            let indexDouble = Double(index)
            rows.append(
                EnergyConsumerSnapshot(
                    id: "proc-\(idx)",
                    pid: Int32(index),
                    displayName: "Proc \(idx)",
                    currentEnergyImpact: indexDouble * 10.0,
                    averageEnergyImpact: indexDouble * 8.0,
                    estimatedDrainShare: indexDouble * 5.0,
                    estimatedPower12hWh: indexDouble * 2.0,
                    preventingSleep: idx.isMultiple(of: 2),
                    highPowerGPUUsage: nil,
                    appNapStatus: nil,
                    cpuPercent: indexDouble,
                    memoryMB: indexDouble * 120.0
                )
            )
        }

        return BatteryEnergyReport(
            generatedAt: Date(),
            battery: BatteryEnergySnapshot(
                updatedAt: Date(),
                deviceName: "Mac",
                machineIdentifier: "Mac16,8",
                chargePercent: 77,
                healthPercent: 98,
                cycleCount: 80,
                isCharging: false,
                powerDrawWatts: 19.2,
                minutesToEmpty: 140,
                minutesToFull: nil,
                temperatureCelsius: 31.1,
                voltageVolts: 12.3,
                amperageAmps: -1.2
            ),
            consumers: rows,
            estimatedMetricTitle: "Estimated Drain Share",
            estimatedMetricExplanation: "estimate"
        )
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

private actor BatteryEnergyControllerServiceStub: BatteryEnergyReportBuilding {
    private var queuedReports: [BatteryEnergyReport]
    private var calls = 0

    init(reports: [BatteryEnergyReport]) {
        self.queuedReports = reports
    }

    func buildBatteryEnergyReport() async -> BatteryEnergyReport {
        calls += 1
        if !queuedReports.isEmpty {
            return queuedReports.removeFirst()
        }
        return BatteryEnergyReport(
            generatedAt: Date(),
            battery: BatteryEnergySnapshot(
                updatedAt: Date(),
                deviceName: "Mac",
                machineIdentifier: "Mac16,8",
                chargePercent: nil,
                healthPercent: nil,
                cycleCount: nil,
                isCharging: nil,
                powerDrawWatts: nil,
                minutesToEmpty: nil,
                minutesToFull: nil,
                temperatureCelsius: nil,
                voltageVolts: nil,
                amperageAmps: nil
            ),
            consumers: [],
            estimatedMetricTitle: "Estimated Drain Share",
            estimatedMetricExplanation: "estimate"
        )
    }

    func callCount() -> Int { calls }
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
