import Foundation
import Testing
@testable import DRay

struct PerformanceUseCaseTests {
    @Test
    @MainActor
    func runDiagnosticsDelegatesToService() async {
        let expected = makeReport(startupCount: 2)
        let performance = PerformanceServiceStub(
            report: expected,
            cleanupReport: StartupCleanupReport(moved: 0, failed: 0, skippedProtected: 0)
        )
        let priorities = ProcessPriorityServiceStub()
        let useCase = PerformanceUseCase(
            performanceService: performance,
            processPriorityService: priorities,
            batteryEnergyService: BatteryEnergyReportServiceStub(report: makeBatteryEnergyReport())
        )

        let report = await useCase.runDiagnostics()

        #expect(report.startupEntries.count == 2)
        #expect(await performance.buildReportCallCount() == 1)
    }

    @Test
    @MainActor
    func cleanupStartupEntriesDelegatesToService() async {
        let expected = StartupCleanupReport(moved: 3, failed: 1, skippedProtected: 2)
        let performance = PerformanceServiceStub(
            report: makeReport(startupCount: 0),
            cleanupReport: expected
        )
        let priorities = ProcessPriorityServiceStub()
        let useCase = PerformanceUseCase(
            performanceService: performance,
            processPriorityService: priorities,
            batteryEnergyService: BatteryEnergyReportServiceStub(report: makeBatteryEnergyReport())
        )
        let entries = [
            StartupEntry(
                name: "com.example.agent.plist",
                url: URL(fileURLWithPath: "/tmp/com.example.agent.plist"),
                source: "User LaunchAgents",
                sizeInBytes: 120
            )
        ]

        let report = await useCase.cleanupStartupEntries(entries)

        #expect(report.moved == 3)
        #expect(report.failed == 1)
        #expect(report.skippedProtected == 2)
        #expect(await performance.lastCleanupEntriesCount() == 1)
    }

    @Test
    @MainActor
    func cpuMemoryAndRestoreDelegationUsesPriorityService() {
        let performance = PerformanceServiceStub(
            report: makeReport(startupCount: 0),
            cleanupReport: StartupCleanupReport(moved: 0, failed: 0, skippedProtected: 0)
        )
        let priorities = ProcessPriorityServiceStub()
        priorities.cpuResult = LoadReliefResult(adjusted: ["A"], skipped: ["B"], failed: [])
        priorities.memoryResult = LoadReliefResult(adjusted: ["M"], skipped: [], failed: ["X"])
        priorities.restoreResult = LoadReliefResult(adjusted: ["R"], skipped: [], failed: [])
        priorities.activeAdjustmentsCount = 7

        let useCase = PerformanceUseCase(
            performanceService: performance,
            processPriorityService: priorities,
            batteryEnergyService: BatteryEnergyReportServiceStub(report: makeBatteryEnergyReport())
        )
        let consumers = [
            ProcessConsumer(pid: 123, name: "Test", cpuPercent: 90, memoryMB: 512, batteryImpactScore: 42)
        ]

        let cpu = useCase.reduceCPULoad(consumers: consumers, limit: 2)
        let memory = useCase.reduceMemoryLoad(consumers: consumers, limit: 4)
        let restore = useCase.restoreAdjustedPriorities(limit: 5)

        #expect(cpu.adjusted == ["A"])
        #expect(cpu.skipped == ["B"])
        #expect(memory.adjusted == ["M"])
        #expect(memory.failed == ["X"])
        #expect(restore.adjusted == ["R"])
        #expect(priorities.lastCPULimit == 2)
        #expect(priorities.lastMemoryLimit == 4)
        #expect(priorities.lastRestoreLimit == 5)
        #expect(useCase.activeAdjustmentsCount == 7)
    }

    @Test
    @MainActor
    func batteryEnergyReportDelegatesToService() async {
        let expected = makeBatteryEnergyReport()
        let performance = PerformanceServiceStub(
            report: makeReport(startupCount: 0),
            cleanupReport: StartupCleanupReport(moved: 0, failed: 0, skippedProtected: 0)
        )
        let priorities = ProcessPriorityServiceStub()
        let battery = BatteryEnergyReportServiceStub(report: expected)
        let useCase = PerformanceUseCase(
            performanceService: performance,
            processPriorityService: priorities,
            batteryEnergyService: battery
        )

        let report = await useCase.loadBatteryEnergyReport()

        #expect(report.consumers.count == expected.consumers.count)
        #expect(await battery.callCount() == 1)
    }

    private func makeReport(startupCount: Int) -> PerformanceReport {
        let entries = (0..<startupCount).map { index in
            StartupEntry(
                name: "entry-\(index).plist",
                url: URL(fileURLWithPath: "/tmp/entry-\(index).plist"),
                source: "Test",
                sizeInBytes: Int64(index + 1)
            )
        }
        return PerformanceReport(
            generatedAt: Date(timeIntervalSince1970: 1_726_000_000),
            startupEntries: entries,
            diskFreeBytes: 500,
            diskTotalBytes: 1_000,
            recommendations: []
        )
    }

    private func makeBatteryEnergyReport() -> BatteryEnergyReport {
        BatteryEnergyReport(
            generatedAt: Date(timeIntervalSince1970: 1_726_000_000),
            battery: BatteryEnergySnapshot(
                updatedAt: Date(timeIntervalSince1970: 1_726_000_000),
                deviceName: "Mac",
                machineIdentifier: "Mac16,8",
                chargePercent: 80,
                healthPercent: 96,
                cycleCount: 120,
                isCharging: false,
                powerDrawWatts: 22.5,
                minutesToEmpty: 180,
                minutesToFull: nil,
                temperatureCelsius: 32.1,
                voltageVolts: 12.2,
                amperageAmps: -1.8
            ),
            consumers: [
                EnergyConsumerSnapshot(
                    id: "browser",
                    pid: 1,
                    displayName: "Browser",
                    currentEnergyImpact: 34,
                    averageEnergyImpact: 30,
                    estimatedDrainShare: 44,
                    estimatedPower12hWh: 110,
                    preventingSleep: false,
                    highPowerGPUUsage: nil,
                    appNapStatus: nil,
                    cpuPercent: 24,
                    memoryMB: 900
                )
            ],
            estimatedMetricTitle: "Estimated Drain Share",
            estimatedMetricExplanation: "estimate"
        )
    }
}

private actor PerformanceServiceStub: PerformanceServicing {
    private let report: PerformanceReport
    private let cleanupReport: StartupCleanupReport
    private var reportCalls = 0
    private var cleanupEntriesCount = 0

    init(report: PerformanceReport, cleanupReport: StartupCleanupReport) {
        self.report = report
        self.cleanupReport = cleanupReport
    }

    func buildReport() async -> PerformanceReport {
        reportCalls += 1
        return report
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) async -> StartupCleanupReport {
        cleanupEntriesCount = entries.count
        return cleanupReport
    }

    func buildReportCallCount() -> Int { reportCalls }
    func lastCleanupEntriesCount() -> Int { cleanupEntriesCount }
}

private actor BatteryEnergyReportServiceStub: BatteryEnergyReportBuilding {
    private let report: BatteryEnergyReport
    private var calls = 0

    init(report: BatteryEnergyReport) {
        self.report = report
    }

    func buildBatteryEnergyReport() async -> BatteryEnergyReport {
        calls += 1
        return report
    }

    func callCount() -> Int { calls }
}

@MainActor
private final class ProcessPriorityServiceStub: ProcessPriorityServicing {
    var activeAdjustmentsCount = 0
    var cpuResult = LoadReliefResult(adjusted: [], skipped: [], failed: [])
    var memoryResult = LoadReliefResult(adjusted: [], skipped: [], failed: [])
    var restoreResult = LoadReliefResult(adjusted: [], skipped: [], failed: [])
    var lastCPULimit: Int?
    var lastMemoryLimit: Int?
    var lastRestoreLimit: Int?

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        lastCPULimit = limit
        return cpuResult
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        lastMemoryLimit = limit
        return memoryResult
    }

    func restoreAdjustedPriorities(limit: Int) -> LoadReliefResult {
        lastRestoreLimit = limit
        return restoreResult
    }
}
