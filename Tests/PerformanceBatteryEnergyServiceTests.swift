import Foundation
import Testing
@testable import DRay

struct PerformanceBatteryEnergyServiceTests {
    @Test
    func serviceAssemblesBatteryAndConsumersIntoReport() async {
        let batteryStub = BatteryDiagnosticsStub(
            snapshot: BatteryDiagnosticsSnapshot(
                updatedAt: Date(timeIntervalSince1970: 1_726_000_000),
                deviceName: "MacBook Pro",
                machineIdentifier: "Mac16,8",
                chargePercent: 63,
                healthPercent: 97,
                currentCapacityMAh: 4_000,
                fullChargeCapacityMAh: 6_000,
                designCapacityMAh: 6_200,
                cycleCount: 54,
                designCycleCount: 1_000,
                temperatureCelsius: 31.2,
                voltageVolts: 12.3,
                amperageAmps: -1.5,
                powerWatts: -19.3,
                adapterWatts: nil,
                isCharging: false,
                minutesToEmpty: 180,
                minutesToFull: nil,
                lowPowerModeEnabled: false,
                manufactureDate: nil
            )
        )
        let consumersStub = EnergyConsumersStub(
            consumers: [
                makeConsumer(id: "alpha", impact: 30),
                makeConsumer(id: "beta", impact: 12)
            ]
        )
        let service = BatteryEnergyService(
            batteryDiagnosticsService: batteryStub,
            energyConsumersService: consumersStub,
            attributionEstimator: BatteryAttributionEstimator()
        )

        let report = await service.buildBatteryEnergyReport()

        #expect(report.battery.deviceName == "MacBook Pro")
        #expect(report.consumers.count == 2)
        #expect(report.estimatedMetricTitle == "Estimated Drain Share")
        #expect(report.consumers.first?.estimatedDrainShare ?? 0 > 0)
    }

    @Test
    func serviceKeepsUnavailableMetricsAsNil() async {
        let batteryStub = BatteryDiagnosticsStub(
            snapshot: BatteryDiagnosticsSnapshot(
                updatedAt: Date(),
                deviceName: "Mac",
                machineIdentifier: "Macmini",
                chargePercent: nil,
                healthPercent: nil,
                currentCapacityMAh: nil,
                fullChargeCapacityMAh: nil,
                designCapacityMAh: nil,
                cycleCount: nil,
                designCycleCount: nil,
                temperatureCelsius: nil,
                voltageVolts: nil,
                amperageAmps: nil,
                powerWatts: nil,
                adapterWatts: nil,
                isCharging: nil,
                minutesToEmpty: nil,
                minutesToFull: nil,
                lowPowerModeEnabled: false,
                manufactureDate: nil
            )
        )
        let consumersStub = EnergyConsumersStub(consumers: [makeConsumer(id: "single", impact: 4)])
        let service = BatteryEnergyService(
            batteryDiagnosticsService: batteryStub,
            energyConsumersService: consumersStub,
            attributionEstimator: BatteryAttributionEstimator()
        )

        let report = await service.buildBatteryEnergyReport()

        #expect(report.battery.chargePercent == nil)
        #expect(report.battery.powerDrawWatts == nil)
        #expect(report.consumers.first?.estimatedPower12hWh == nil)
    }

    private func makeConsumer(id: String, impact: Double) -> EnergyConsumerSnapshot {
        EnergyConsumerSnapshot(
            id: id,
            pid: 1,
            displayName: id,
            currentEnergyImpact: impact,
            averageEnergyImpact: impact * 0.8,
            estimatedDrainShare: 0,
            estimatedPower12hWh: nil,
            preventingSleep: false,
            highPowerGPUUsage: nil,
            appNapStatus: nil,
            cpuPercent: impact,
            memoryMB: 300
        )
    }
}

private struct BatteryDiagnosticsStub: BatteryDiagnosticsProviding {
    let snapshot: BatteryDiagnosticsSnapshot

    func fetchSnapshot() -> BatteryDiagnosticsSnapshot {
        snapshot
    }
}

private actor EnergyConsumersStub: EnergyConsumersProviding {
    let consumers: [EnergyConsumerSnapshot]

    init(consumers: [EnergyConsumerSnapshot]) {
        self.consumers = consumers
    }

    func fetchEnergyConsumers(now: Date) async -> [EnergyConsumerSnapshot] {
        consumers
    }
}
