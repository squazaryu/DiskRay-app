import Foundation

protocol BatteryDiagnosticsProviding: Sendable {
    func fetchSnapshot() -> BatteryDiagnosticsSnapshot
}

protocol BatteryEnergyReportBuilding: Sendable {
    func buildBatteryEnergyReport() async -> BatteryEnergyReport
}

struct BatteryEnergyService: BatteryEnergyReportBuilding, Sendable {
    private let batteryDiagnosticsService: any BatteryDiagnosticsProviding
    private let energyConsumersService: any EnergyConsumersProviding
    private let attributionEstimator: any BatteryAttributionEstimating

    init(
        batteryDiagnosticsService: any BatteryDiagnosticsProviding,
        energyConsumersService: any EnergyConsumersProviding,
        attributionEstimator: any BatteryAttributionEstimating
    ) {
        self.batteryDiagnosticsService = batteryDiagnosticsService
        self.energyConsumersService = energyConsumersService
        self.attributionEstimator = attributionEstimator
    }

    func buildBatteryEnergyReport() async -> BatteryEnergyReport {
        let diagnostics = batteryDiagnosticsService.fetchSnapshot()
        let battery = BatteryEnergySnapshot(
            updatedAt: diagnostics.updatedAt,
            deviceName: diagnostics.deviceName,
            machineIdentifier: diagnostics.machineIdentifier,
            chargePercent: diagnostics.chargePercent,
            healthPercent: diagnostics.healthPercent,
            cycleCount: diagnostics.cycleCount,
            isCharging: diagnostics.isCharging,
            powerDrawWatts: diagnostics.powerWatts,
            minutesToEmpty: diagnostics.minutesToEmpty,
            minutesToFull: diagnostics.minutesToFull,
            temperatureCelsius: diagnostics.temperatureCelsius,
            voltageVolts: diagnostics.voltageVolts,
            amperageAmps: diagnostics.amperageAmps
        )

        let consumers = await energyConsumersService.fetchEnergyConsumers(now: Date())
        let estimatedConsumers = attributionEstimator.applyEstimate(
            consumers: consumers,
            battery: battery
        )

        return BatteryEnergyReport(
            generatedAt: Date(),
            battery: battery,
            consumers: estimatedConsumers,
            estimatedMetricTitle: "Estimated Drain Share",
            estimatedMetricExplanation: "Estimate based on macOS process activity and energy telemetry, not an official per-app battery percentage."
        )
    }
}

extension BatteryDiagnosticsService: BatteryDiagnosticsProviding {}

