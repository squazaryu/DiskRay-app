import Foundation
import Darwin
import IOKit.ps
import AppKit

struct ProcessConsumer: Identifiable, Sendable {
    let id = UUID()
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
    let batteryImpactScore: Double
}

struct LiveSystemSnapshot: Sendable {
    let updatedAt: Date
    let cpuLoadPercent: Double
    let cpuUserPercent: Double
    let cpuSystemPercent: Double
    let memoryUsedBytes: Int64
    let memoryTotalBytes: Int64
    let memoryPressurePercent: Double
    let diskFreeBytes: Int64
    let diskTotalBytes: Int64
    let batteryLevelPercent: Int?
    let batteryIsCharging: Bool?
    let batteryMinutesRemaining: Int?
    let networkDownBytesPerSecond: Double
    let networkUpBytesPerSecond: Double
    let uptimeSeconds: TimeInterval
    let topCPUConsumers: [ProcessConsumer]
    let topMemoryConsumers: [ProcessConsumer]
    let topBatteryConsumers: [ProcessConsumer]

    static let empty = LiveSystemSnapshot(
        updatedAt: Date(),
        cpuLoadPercent: 0,
        cpuUserPercent: 0,
        cpuSystemPercent: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: Int64(ProcessInfo.processInfo.physicalMemory),
        memoryPressurePercent: 0,
        diskFreeBytes: 0,
        diskTotalBytes: 0,
        batteryLevelPercent: nil,
        batteryIsCharging: nil,
        batteryMinutesRemaining: nil,
        networkDownBytesPerSecond: 0,
        networkUpBytesPerSecond: 0,
        uptimeSeconds: ProcessInfo.processInfo.systemUptime,
        topCPUConsumers: [],
        topMemoryConsumers: [],
        topBatteryConsumers: []
    )
}

@MainActor
final class LiveSystemMetricsMonitor: ObservableObject {
    @Published private(set) var snapshot: LiveSystemSnapshot = .empty

    private let updateInterval: TimeInterval
    private let heavySampleTickInterval: Int
    private let powerNotifier = PowerSourceNotifier()
    private var timer: Timer?
    private var previousCPU: CPUCounters?
    private var previousNetwork: NetworkCounters?
    private var cachedCPUConsumers: [ProcessConsumer] = []
    private var cachedMemoryConsumers: [ProcessConsumer] = []
    private var cachedBatteryConsumers: [ProcessConsumer] = []
    private var batterySmoother = BatterySmoother()
    private var tickCounter = 0

    init(updateInterval: TimeInterval = 1.0, heavySamplePeriod: TimeInterval = 4.0) {
        let safeInterval = max(0.4, updateInterval)
        self.updateInterval = safeInterval
        let safeHeavyPeriod = max(safeInterval, heavySamplePeriod)
        self.heavySampleTickInterval = max(1, Int((safeHeavyPeriod / safeInterval).rounded()))
    }

    func start() {
        guard timer == nil else { return }
        powerNotifier.onPowerSourceChanged = { [weak self] in
            Task { @MainActor in
                self?.updateBatteryFromSystemEvent()
            }
        }
        powerNotifier.start()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        powerNotifier.stop()
        powerNotifier.onPowerSourceChanged = nil
    }

    private func update() {
        let now = Date()
        let cpu = cpuSample()
        let memory = memorySample()
        let disk = diskSample()
        let battery = batterySmoother.ingest(
            batterySample(),
            source: .timer,
            now: now
        )
        let network = networkSample(at: now)
        tickCounter += 1
        if tickCounter.isMultiple(of: heavySampleTickInterval) || cachedCPUConsumers.isEmpty {
            let consumers = processConsumersSample()
            cachedCPUConsumers = consumers.topCPU
            cachedMemoryConsumers = consumers.topMemory
            cachedBatteryConsumers = consumers.topBattery
        }

        snapshot = LiveSystemSnapshot(
            updatedAt: now,
            cpuLoadPercent: cpu.totalLoad,
            cpuUserPercent: cpu.user,
            cpuSystemPercent: cpu.system,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            memoryPressurePercent: memory.pressure,
            diskFreeBytes: disk.free,
            diskTotalBytes: disk.total,
            batteryLevelPercent: battery.percent,
            batteryIsCharging: battery.isCharging,
            batteryMinutesRemaining: battery.minutesRemaining,
            networkDownBytesPerSecond: network.downPerSecond,
            networkUpBytesPerSecond: network.upPerSecond,
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            topCPUConsumers: cachedCPUConsumers,
            topMemoryConsumers: cachedMemoryConsumers,
            topBatteryConsumers: cachedBatteryConsumers
        )
    }

    private func updateBatteryFromSystemEvent() {
        let now = Date()
        let battery = batterySmoother.ingest(
            batterySample(),
            source: .event,
            now: now
        )
        snapshot = LiveSystemSnapshot(
            updatedAt: now,
            cpuLoadPercent: snapshot.cpuLoadPercent,
            cpuUserPercent: snapshot.cpuUserPercent,
            cpuSystemPercent: snapshot.cpuSystemPercent,
            memoryUsedBytes: snapshot.memoryUsedBytes,
            memoryTotalBytes: snapshot.memoryTotalBytes,
            memoryPressurePercent: snapshot.memoryPressurePercent,
            diskFreeBytes: snapshot.diskFreeBytes,
            diskTotalBytes: snapshot.diskTotalBytes,
            batteryLevelPercent: battery.percent,
            batteryIsCharging: battery.isCharging,
            batteryMinutesRemaining: battery.minutesRemaining,
            networkDownBytesPerSecond: snapshot.networkDownBytesPerSecond,
            networkUpBytesPerSecond: snapshot.networkUpBytesPerSecond,
            uptimeSeconds: snapshot.uptimeSeconds,
            topCPUConsumers: snapshot.topCPUConsumers,
            topMemoryConsumers: snapshot.topMemoryConsumers,
            topBatteryConsumers: snapshot.topBatteryConsumers
        )
    }

    private func cpuSample() -> (totalLoad: Double, user: Double, system: Double) {
        guard let current = readCPUCounters() else { return (0, 0, 0) }
        defer { previousCPU = current }

        guard let previousCPU else {
            return (0, 0, 0)
        }

        let userDiff = max(0, Int64(current.user) - Int64(previousCPU.user))
        let niceDiff = max(0, Int64(current.nice) - Int64(previousCPU.nice))
        let systemDiff = max(0, Int64(current.system) - Int64(previousCPU.system))
        let idleDiff = max(0, Int64(current.idle) - Int64(previousCPU.idle))

        let totalTicks = Double(userDiff + niceDiff + systemDiff + idleDiff)
        guard totalTicks > 0 else { return (0, 0, 0) }

        let userPercent = (Double(userDiff + niceDiff) / totalTicks) * 100
        let systemPercent = (Double(systemDiff) / totalTicks) * 100
        let load = (Double(userDiff + niceDiff + systemDiff) / totalTicks) * 100
        return (load, userPercent, systemPercent)
    }

    private func readCPUCounters() -> CPUCounters? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUCounters(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private func memorySample() -> (used: Int64, total: Int64, pressure: Double) {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, total, 0)
        }

        var pageSizeValue: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSizeValue)
        let pageSize = Int64(pageSizeValue)
        let active = Int64(stats.active_count) * pageSize
        let inactive = Int64(stats.inactive_count) * pageSize
        let wired = Int64(stats.wire_count) * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize

        // Inactive pages are typically reclaimable; counting them fully inflates "pressure".
        let used = active + inactive + wired + compressed
        let workingSet = active + wired + compressed
        var pressure = total > 0 ? (Double(workingSet) / Double(total)) * 100.0 : 0

        // Extra pressure boost when compressed memory is significant.
        var compressedShare = 0.0
        if total > 0 {
            compressedShare = Double(compressed) / Double(total)
            if compressedShare > 0.12 {
                pressure += min(18.0, compressedShare * 60.0)
            }
        }
        if let systemPressure = systemMemoryPressureLevel() {
            let kernelMapped = systemPressure * 0.72
            pressure = max(kernelMapped, pressure * 0.35)
            if compressedShare > 0.20 {
                pressure += 6
            }
        }
        pressure = min(100, max(0, pressure))
        return (used, total, pressure)
    }

    private func systemMemoryPressureLevel() -> Double? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0)
        guard result == 0 else { return nil }
        return min(100, max(0, Double(level)))
    }

    private func diskSample() -> (free: Int64, total: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
            return (free, total)
        } catch {
            return (0, 0)
        }
    }

    private func batterySample() -> (percent: Int?, isCharging: Bool?, minutesRemaining: Int?) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return (nil, nil, nil)
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

            let percent: Int?
            if let current, let max, max > 0 {
                percent = Int((Double(current) / Double(max)) * 100.0)
            } else {
                percent = nil
            }

            let minutes: Int?
            if let isCharging, isCharging {
                minutes = normalizedMinutes(timeToFull)
            } else {
                minutes = normalizedMinutes(timeToEmpty)
            }

            return (percent, isCharging, minutes)
        }

        return (nil, nil, nil)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String {
            switch text.lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func normalizedMinutes(_ value: Int?) -> Int? {
        guard let value, value >= 0 else { return nil }
        // Extremely large values are often noise while system is still estimating.
        guard value <= 72 * 60 else { return nil }
        return value
    }

    private func networkSample(at now: Date) -> (downPerSecond: Double, upPerSecond: Double) {
        guard let current = readNetworkCounters(at: now) else {
            return (0, 0)
        }
        defer { previousNetwork = current }

        guard let previousNetwork else {
            return (0, 0)
        }

        let dt = max(now.timeIntervalSince(previousNetwork.timestamp), 0.2)
        let downDiff = max(0, Int64(current.inboundBytes) - Int64(previousNetwork.inboundBytes))
        let upDiff = max(0, Int64(current.outboundBytes) - Int64(previousNetwork.outboundBytes))

        return (Double(downDiff) / dt, Double(upDiff) / dt)
    }

    private func readNetworkCounters(at now: Date) -> NetworkCounters? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let start = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        var inbound: UInt64 = 0
        var outbound: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = start

        while let entry = current {
            let flags = Int32(entry.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp, !isLoopback, let data = entry.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                inbound += UInt64(ifData.ifi_ibytes)
                outbound += UInt64(ifData.ifi_obytes)
            }
            current = entry.pointee.ifa_next
        }

        return NetworkCounters(timestamp: now, inboundBytes: inbound, outboundBytes: outbound)
    }

    private func processConsumersSample() -> (topCPU: [ProcessConsumer], topMemory: [ProcessConsumer], topBattery: [ProcessConsumer]) {
        let command = "/bin/ps"
        let args = ["-A", "-o", "pid=,%cpu=,rss=,comm="]
        let output = runCommand(command, arguments: args)
        guard !output.isEmpty else { return ([], [], []) }

        let runningApps = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap { app -> (Int32, String)? in
                guard app.processIdentifier > 0, let name = app.localizedName, !name.isEmpty else { return nil }
                // Prioritize user-facing apps; fallback to any app if needed.
                if app.activationPolicy == .regular || app.activationPolicy == .accessory {
                    return (app.processIdentifier, name)
                }
                return nil
            }
        )

        var rows: [ProcessConsumer] = []
        rows.reserveCapacity(64)

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Double(parts[2]),
                  cpu >= 0 else { continue }

            let processName = String(parts[3])
            let appName = runningApps[pid] ?? normalizedProcessName(processName)
            guard !appName.isEmpty else { continue }

            let memoryMB = rssKB / 1024.0
            let batteryImpact = cpu * 1.7 + memoryMB * 0.02
            rows.append(
                ProcessConsumer(
                    pid: pid,
                    name: appName,
                    cpuPercent: cpu,
                    memoryMB: memoryMB,
                    batteryImpactScore: batteryImpact
                )
            )
        }

        // Deduplicate by displayed app name, keep the most expensive row.
        var byName: [String: ProcessConsumer] = [:]
        for row in rows {
            if let existing = byName[row.name] {
                if row.cpuPercent + row.memoryMB * 0.01 > existing.cpuPercent + existing.memoryMB * 0.01 {
                    byName[row.name] = row
                }
            } else {
                byName[row.name] = row
            }
        }

        let unique = Array(byName.values)
        let topCPU = unique
            .filter { $0.cpuPercent > 0.1 }
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(5)
        let topMemory = unique
            .filter { $0.memoryMB > 200 }
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(5)
        let topBattery = unique
            .filter { $0.batteryImpactScore > 0.3 }
            .sorted { $0.batteryImpactScore > $1.batteryImpactScore }
            .prefix(5)

        return (Array(topCPU), Array(topMemory), Array(topBattery))
    }

    private func normalizedProcessName(_ raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        if raw.contains("/") {
            return URL(fileURLWithPath: raw).lastPathComponent
        }
        return raw
    }

    private func runCommand(_ launchPath: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct CPUCounters {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

private struct NetworkCounters {
    let timestamp: Date
    let inboundBytes: UInt64
    let outboundBytes: UInt64
}

private enum BatteryUpdateSource {
    case timer
    case event
}

private struct BatterySmoother {
    private var smoothedPercent: Double?
    private var smoothedMinutes: Double?
    private var lastCharging: Bool?
    private var lastUpdateAt: Date?

    mutating func ingest(
        _ sample: (percent: Int?, isCharging: Bool?, minutesRemaining: Int?),
        source: BatteryUpdateSource,
        now: Date
    ) -> (percent: Int?, isCharging: Bool?, minutesRemaining: Int?) {
        let elapsed = max(0.2, now.timeIntervalSince(lastUpdateAt ?? now))
        defer {
            lastUpdateAt = now
            lastCharging = sample.isCharging
        }

        guard let rawPercent = sample.percent else {
            smoothedPercent = nil
            smoothedMinutes = nil
            return (nil, sample.isCharging, nil)
        }

        let chargingChanged = lastCharging != nil && sample.isCharging != lastCharging

        if smoothedPercent == nil || chargingChanged {
            smoothedPercent = Double(rawPercent)
        } else if let previous = smoothedPercent {
            let baseAlpha = source == .event ? 0.68 : 0.24
            let elapsedFactor = min(2.1, max(0.6, elapsed))
            let alpha = max(0.16, min(0.88, baseAlpha * elapsedFactor))
            smoothedPercent = previous + (Double(rawPercent) - previous) * alpha
        }

        let outputPercent = max(0, min(100, Int((smoothedPercent ?? Double(rawPercent)).rounded())))

        let outputMinutes: Int?
        if let rawMinutes = sample.minutesRemaining {
            if smoothedMinutes == nil || chargingChanged {
                smoothedMinutes = Double(rawMinutes)
            } else if let previous = smoothedMinutes {
                let deltaLimit = source == .event ? 80.0 : 28.0
                let boundedRaw = previous + min(deltaLimit, max(-deltaLimit, Double(rawMinutes) - previous))
                let baseAlpha = source == .event ? 0.50 : 0.20
                let elapsedFactor = min(2.0, max(0.6, elapsed))
                let alpha = max(0.12, min(0.72, baseAlpha * elapsedFactor))
                smoothedMinutes = previous + (boundedRaw - previous) * alpha
            }
            outputMinutes = max(0, Int((smoothedMinutes ?? Double(rawMinutes)).rounded()))
        } else {
            if let previous = smoothedMinutes, elapsed < 80 {
                outputMinutes = max(0, Int(previous.rounded()))
            } else {
                smoothedMinutes = nil
                outputMinutes = nil
            }
        }

        return (outputPercent, sample.isCharging, outputMinutes)
    }
}

private final class PowerSourceNotifier {
    var onPowerSourceChanged: (() -> Void)?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard runLoopSource == nil else { return }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let unmanaged = IOPSNotificationCreateRunLoopSource(powerSourceChanged, context) else { return }
        let source = unmanaged.takeRetainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
    }

    func stop() {
        guard let runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        self.runLoopSource = nil
    }

    deinit {
        stop()
    }
}

private func powerSourceChanged(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let notifier = Unmanaged<PowerSourceNotifier>.fromOpaque(context).takeUnretainedValue()
    notifier.onPowerSourceChanged?()
}
