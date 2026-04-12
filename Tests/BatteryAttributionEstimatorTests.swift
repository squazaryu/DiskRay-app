import Foundation
import Testing
@testable import DRay

struct BatteryAttributionEstimatorTests {
    @Test
    func estimatedDrainShareSumsCloseToHundred() {
        let estimator = BatteryAttributionEstimator()
        let battery = BatteryEnergySnapshot(
            updatedAt: Date(),
            deviceName: "Mac",
            machineIdentifier: "Mac16,8",
            chargePercent: 70,
            healthPercent: 96,
            cycleCount: 100,
            isCharging: false,
            powerDrawWatts: 24,
            minutesToEmpty: 160,
            minutesToFull: nil,
            temperatureCelsius: 31.0,
            voltageVolts: 12.2,
            amperageAmps: -1.8
        )
        let consumers = [
            makeConsumer(id: "a", current: 40, average: 30, sleep: false),
            makeConsumer(id: "b", current: 20, average: 15, sleep: true),
            makeConsumer(id: "c", current: 10, average: 11, sleep: false)
        ]

        let estimated = estimator.applyEstimate(consumers: consumers, battery: battery)
        let sum = estimated.reduce(0.0) { $0 + $1.estimatedDrainShare }

        #expect(abs(sum - 100.0) < 0.001)
        #expect(estimated.first?.estimatedPower12hWh != nil)
    }

    @Test
    func chargingOrUnknownPowerDoesNotReport12hEstimate() {
        let estimator = BatteryAttributionEstimator()
        let chargingBattery = BatteryEnergySnapshot(
            updatedAt: Date(),
            deviceName: "Mac",
            machineIdentifier: "Mac16,8",
            chargePercent: 80,
            healthPercent: 95,
            cycleCount: 50,
            isCharging: true,
            powerDrawWatts: 18,
            minutesToEmpty: nil,
            minutesToFull: 80,
            temperatureCelsius: 30,
            voltageVolts: 12.1,
            amperageAmps: 1.2
        )
        let unknownPowerBattery = BatteryEnergySnapshot(
            updatedAt: Date(),
            deviceName: "Mac",
            machineIdentifier: "Mac16,8",
            chargePercent: 50,
            healthPercent: 93,
            cycleCount: 200,
            isCharging: false,
            powerDrawWatts: nil,
            minutesToEmpty: 110,
            minutesToFull: nil,
            temperatureCelsius: 32,
            voltageVolts: nil,
            amperageAmps: nil
        )
        let consumers = [makeConsumer(id: "only", current: 14, average: 10, sleep: false)]

        let chargingResult = estimator.applyEstimate(consumers: consumers, battery: chargingBattery)
        let unknownPowerResult = estimator.applyEstimate(consumers: consumers, battery: unknownPowerBattery)

        #expect(chargingResult.first?.estimatedPower12hWh == nil)
        #expect(unknownPowerResult.first?.estimatedPower12hWh == nil)
    }

    @Test
    func estimatorSortsByEstimatedShareDescending() {
        let estimator = BatteryAttributionEstimator()
        let battery = BatteryEnergySnapshot(
            updatedAt: Date(),
            deviceName: "Mac",
            machineIdentifier: "Mac16,8",
            chargePercent: 40,
            healthPercent: 90,
            cycleCount: 400,
            isCharging: false,
            powerDrawWatts: 12,
            minutesToEmpty: 95,
            minutesToFull: nil,
            temperatureCelsius: 33,
            voltageVolts: 12,
            amperageAmps: -1
        )
        let consumers = [
            makeConsumer(id: "small", current: 5, average: 4, sleep: false),
            makeConsumer(id: "big", current: 45, average: 30, sleep: false)
        ]

        let estimated = estimator.applyEstimate(consumers: consumers, battery: battery)

        #expect(estimated.first?.id == "big")
        #expect(estimated.last?.id == "small")
    }

    private func makeConsumer(
        id: String,
        current: Double,
        average: Double,
        sleep: Bool
    ) -> EnergyConsumerSnapshot {
        EnergyConsumerSnapshot(
            id: id,
            pid: 1,
            displayName: id,
            currentEnergyImpact: current,
            averageEnergyImpact: average,
            estimatedDrainShare: 0,
            estimatedPower12hWh: nil,
            preventingSleep: sleep,
            highPowerGPUUsage: nil,
            appNapStatus: nil,
            cpuPercent: current,
            memoryMB: 100
        )
    }
}

