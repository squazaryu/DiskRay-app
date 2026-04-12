import Foundation

struct BatteryEnergySnapshot: Sendable {
    let updatedAt: Date
    let deviceName: String
    let machineIdentifier: String
    let chargePercent: Int?
    let healthPercent: Int?
    let cycleCount: Int?
    let isCharging: Bool?
    let powerDrawWatts: Double?
    let minutesToEmpty: Int?
    let minutesToFull: Int?
    let temperatureCelsius: Double?
    let voltageVolts: Double?
    let amperageAmps: Double?
}

struct EnergyConsumerSnapshot: Identifiable, Sendable {
    let id: String
    let pid: Int32
    let displayName: String
    let currentEnergyImpact: Double
    let averageEnergyImpact: Double
    let estimatedDrainShare: Double
    let estimatedPower12hWh: Double?
    let preventingSleep: Bool
    let highPowerGPUUsage: Bool?
    let appNapStatus: Bool?
    let cpuPercent: Double
    let memoryMB: Double
}

struct BatteryEnergyReport: Sendable {
    let generatedAt: Date
    let battery: BatteryEnergySnapshot
    let consumers: [EnergyConsumerSnapshot]
    let estimatedMetricTitle: String
    let estimatedMetricExplanation: String
}

