import Foundation
import Darwin
import IOKit
import IOKit.ps

struct BatteryDiagnosticsSnapshot: Sendable {
    let updatedAt: Date
    let deviceName: String
    let machineIdentifier: String
    let chargePercent: Int?
    let healthPercent: Int?
    let currentCapacityMAh: Int?
    let fullChargeCapacityMAh: Int?
    let designCapacityMAh: Int?
    let cycleCount: Int?
    let designCycleCount: Int?
    let temperatureCelsius: Double?
    let voltageVolts: Double?
    let amperageAmps: Double?
    let powerWatts: Double?
    let adapterWatts: Double?
    let isCharging: Bool?
    let minutesToEmpty: Int?
    let minutesToFull: Int?
    let lowPowerModeEnabled: Bool
    let manufactureDate: String?
}

struct BatteryDiagnosticsService: Sendable {
    func fetchSnapshot() -> BatteryDiagnosticsSnapshot {
        let props = readSmartBatteryProperties()
        let power = readPowerSource()

        let currentCapacity = intValue(props["AppleRawCurrentCapacity"]) ?? intValue(props["CurrentCapacity"])
        let fullCapacity = intValue(props["AppleRawMaxCapacity"]) ?? intValue(props["MaxCapacity"])
        let designCapacity = intValue(props["DesignCapacity"])
        let chargePercentFromCapacity: Int? = {
            guard let currentCapacity, let fullCapacity, fullCapacity > 0 else { return nil }
            return Int((Double(currentCapacity) / Double(fullCapacity)) * 100)
        }()
        let chargePercent = power.percent ?? chargePercentFromCapacity

        let healthPercent: Int? = {
            guard let fullCapacity, let designCapacity, designCapacity > 0 else { return nil }
            return Int((Double(fullCapacity) / Double(designCapacity)) * 100)
        }()

        let voltageVolts = normalizeVoltage(intValue(props["Voltage"]))
        let amperageAmps = normalizeAmperage(intValue(props["Amperage"]))
        let powerWatts: Double? = {
            guard let voltageVolts, let amperageAmps else { return nil }
            return voltageVolts * amperageAmps
        }()

        let temperatureCelsius = normalizeTemperature(intValue(props["Temperature"]))
        let machineIdentifier = readSysctlString("hw.model") ?? "n/a"
        let deviceName = Host.current().localizedName ?? "Mac"
        let manufactureDate = decodeManufactureDate(intValue(props["ManufactureDate"]))
        let adapterWatts = adapterWattage(from: props)
        let chargingState = resolvedChargingState(
            batteryFlag: boolValue(props["IsCharging"]),
            powerFlag: power.isCharging,
            externalConnected: boolValue(props["ExternalConnected"]),
            fullyCharged: boolValue(props["FullyCharged"]),
            chargePercent: chargePercent
        )
        let resolvedMinutesToFull = resolvedMinutesToFull(
            powerMinutesToFull: power.minutesToFull,
            isCharging: chargingState,
            currentCapacityMAh: currentCapacity,
            fullChargeCapacityMAh: fullCapacity,
            amperageAmps: amperageAmps,
            powerWatts: powerWatts,
            voltageVolts: voltageVolts
        )
        let resolvedMinutesToEmpty = resolvedMinutesToEmpty(
            powerMinutesToEmpty: power.minutesToEmpty,
            isCharging: chargingState,
            currentCapacityMAh: currentCapacity,
            amperageAmps: amperageAmps,
            powerWatts: powerWatts,
            voltageVolts: voltageVolts
        )

        return BatteryDiagnosticsSnapshot(
            updatedAt: Date(),
            deviceName: deviceName,
            machineIdentifier: machineIdentifier,
            chargePercent: chargePercent,
            healthPercent: healthPercent,
            currentCapacityMAh: currentCapacity,
            fullChargeCapacityMAh: fullCapacity,
            designCapacityMAh: designCapacity,
            cycleCount: intValue(props["CycleCount"]),
            designCycleCount: intValue(props["DesignCycleCount9C"]) ?? intValue(props["DesignCycleCount"]),
            temperatureCelsius: temperatureCelsius,
            voltageVolts: voltageVolts,
            amperageAmps: amperageAmps,
            powerWatts: powerWatts,
            adapterWatts: adapterWatts,
            isCharging: chargingState,
            minutesToEmpty: resolvedMinutesToEmpty,
            minutesToFull: resolvedMinutesToFull,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            manufactureDate: manufactureDate
        )
    }

    private func resolvedMinutesToFull(
        powerMinutesToFull: Int?,
        isCharging: Bool?,
        currentCapacityMAh: Int?,
        fullChargeCapacityMAh: Int?,
        amperageAmps: Double?,
        powerWatts: Double?,
        voltageVolts: Double?
    ) -> Int? {
        if let powerMinutesToFull, (0...48 * 60).contains(powerMinutesToFull) {
            return powerMinutesToFull
        }
        guard isCharging == true,
              let currentCapacityMAh,
              let fullChargeCapacityMAh,
              fullChargeCapacityMAh > 0 else {
            return nil
        }
        if currentCapacityMAh >= fullChargeCapacityMAh {
            return 0
        }
        let currentA = chargingCurrentAmps(amperageAmps: amperageAmps, powerWatts: powerWatts, voltageVolts: voltageVolts)
        guard let currentA, currentA > 0.02 else { return nil }
        let remainingMAh = Double(fullChargeCapacityMAh - currentCapacityMAh)
        let minutes = Int((remainingMAh / (currentA * 1000.0)) * 60.0)
        return normalizeMinutes(minutes)
    }

    private func resolvedMinutesToEmpty(
        powerMinutesToEmpty: Int?,
        isCharging: Bool?,
        currentCapacityMAh: Int?,
        amperageAmps: Double?,
        powerWatts: Double?,
        voltageVolts: Double?
    ) -> Int? {
        if let powerMinutesToEmpty, (0...48 * 60).contains(powerMinutesToEmpty) {
            return powerMinutesToEmpty
        }
        guard isCharging == false, let currentCapacityMAh else { return nil }
        let currentA = dischargingCurrentAmps(amperageAmps: amperageAmps, powerWatts: powerWatts, voltageVolts: voltageVolts)
        guard let currentA, currentA > 0.02 else { return nil }
        let minutes = Int((Double(currentCapacityMAh) / (currentA * 1000.0)) * 60.0)
        return normalizeMinutes(minutes)
    }

    private func resolvedChargingState(
        batteryFlag: Bool?,
        powerFlag: Bool?,
        externalConnected: Bool?,
        fullyCharged: Bool?,
        chargePercent: Int?
    ) -> Bool? {
        if let batteryFlag {
            return batteryFlag
        }
        if let powerFlag {
            return powerFlag
        }
        if let externalConnected {
            if externalConnected {
                if fullyCharged == true { return true }
                if let chargePercent, chargePercent >= 100 { return true }
                return true
            }
            return false
        }
        return nil
    }

    private func chargingCurrentAmps(amperageAmps: Double?, powerWatts: Double?, voltageVolts: Double?) -> Double? {
        if let amps = amperageAmps, amps > 0 {
            return amps
        }
        if let watts = powerWatts, watts > 0, let volts = voltageVolts, volts > 1 {
            return watts / volts
        }
        return nil
    }

    private func dischargingCurrentAmps(amperageAmps: Double?, powerWatts: Double?, voltageVolts: Double?) -> Double? {
        if let amps = amperageAmps, amps < 0 {
            return abs(amps)
        }
        if let watts = powerWatts, watts < 0, let volts = voltageVolts, volts > 1 {
            return abs(watts / volts)
        }
        return nil
    }

    private func normalizeMinutes(_ value: Int) -> Int? {
        guard value >= 0 else { return nil }
        return min(value, 48 * 60)
    }

    private func readSmartBatteryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &unmanagedProperties,
            kCFAllocatorDefault,
            0
        )
        guard result == KERN_SUCCESS, let unmanagedProperties else { return [:] }
        return unmanagedProperties.takeRetainedValue() as? [String: Any] ?? [:]
    }

    private func readPowerSource() -> (percent: Int?, isCharging: Bool?, minutesToEmpty: Int?, minutesToFull: Int?) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return (nil, nil, nil, nil)
        }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let current = intValue(desc[kIOPSCurrentCapacityKey as String])
            let max = intValue(desc[kIOPSMaxCapacityKey as String])
            let isCharging = boolValue(desc[kIOPSIsChargingKey as String])
            let timeToEmpty = intValue(desc[kIOPSTimeToEmptyKey as String])
            let timeToFull = intValue(desc[kIOPSTimeToFullChargeKey as String])

            let percent: Int? = {
                guard let current, let max, max > 0 else { return nil }
                return Int((Double(current) / Double(max)) * 100.0)
            }()

            return (percent, isCharging, timeToEmpty, timeToFull)
        }
        return (nil, nil, nil, nil)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let intValue = value as? Int { return intValue }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool { return boolValue }
        if let number = value as? NSNumber { return number.boolValue }
        if let stringValue = value as? String {
            switch stringValue.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private func normalizeTemperature(_ raw: Int?) -> Double? {
        guard let raw else { return nil }
        if raw > 1000 { return Double(raw) / 100.0 }
        if raw > 200 { return Double(raw) / 10.0 }
        return Double(raw)
    }

    private func normalizeVoltage(_ raw: Int?) -> Double? {
        guard let raw else { return nil }
        if raw > 1000 { return Double(raw) / 1000.0 }
        return Double(raw)
    }

    private func normalizeAmperage(_ raw: Int?) -> Double? {
        guard let raw else { return nil }
        return Double(raw) / 1000.0
    }

    private func decodeManufactureDate(_ raw: Int?) -> String? {
        guard let raw else { return nil }
        let day = raw & 0x1F
        let month = (raw >> 5) & 0x0F
        let year = 1980 + ((raw >> 9) & 0x7F)
        guard (1...31).contains(day), (1...12).contains(month), year >= 1980 else {
            return nil
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func adapterWattage(from properties: [String: Any]) -> Double? {
        guard let adapterDetails = properties["AdapterDetails"] as? [String: Any] else { return nil }
        if let watts = adapterDetails["Watts"] as? NSNumber {
            return watts.doubleValue
        }
        return nil
    }

    private func readSysctlString(_ key: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
        let validBytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard !validBytes.isEmpty else { return nil }
        return String(decoding: validBytes, as: UTF8.self)
    }
}
