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

enum MacEnergyMode: Int, CaseIterable, Identifiable, Sendable, Hashable {
    case automatic = 0
    case lowPower = 1
    case highPower = 2

    var id: Int { rawValue }
}

enum MacEnergyPowerSource: String, CaseIterable, Identifiable, Sendable, Hashable {
    case battery
    case charger

    var id: String { rawValue }

    var pmsetArgument: String {
        switch self {
        case .battery: return "-b"
        case .charger: return "-c"
        }
    }
}

struct MacEnergyModeSettings: Sendable, Equatable {
    let generatedAt: Date
    let batteryMode: MacEnergyMode?
    let chargerMode: MacEnergyMode?
    let supportsLowPowerMode: Bool
    let supportsHighPowerMode: Bool
    let currentPowerSource: MacEnergyPowerSource?
    let errorMessage: String?

    func mode(for source: MacEnergyPowerSource) -> MacEnergyMode? {
        switch source {
        case .battery: return batteryMode
        case .charger: return chargerMode
        }
    }
}

struct MacEnergyModeUpdateResult: Sendable, Equatable {
    let source: MacEnergyPowerSource
    let requestedMode: MacEnergyMode
    let settings: MacEnergyModeSettings
    let errorMessage: String?

    var succeeded: Bool {
        errorMessage == nil
    }
}
