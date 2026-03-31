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

    private var timer: Timer?
    private var previousCPU: CPUCounters?
    private var previousNetwork: NetworkCounters?
    private var cachedCPUConsumers: [ProcessConsumer] = []
    private var cachedMemoryConsumers: [ProcessConsumer] = []
    private var cachedBatteryConsumers: [ProcessConsumer] = []
    private var tickCounter = 0

    func start() {
        guard timer == nil else { return }
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        let now = Date()
        let cpu = cpuSample()
        let memory = memorySample()
        let disk = diskSample()
        let battery = batterySample()
        let network = networkSample(at: now)
        tickCounter += 1
        if tickCounter.isMultiple(of: 4) || cachedCPUConsumers.isEmpty {
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
        let used = active + inactive + wired + compressed
        let workingSet = active + wired + compressed
        var pressure = total > 0 ? (Double(workingSet) / Double(total)) * 100.0 : 0
        if let systemPressure = systemMemoryPressureLevel() {
            pressure = max(systemPressure * 0.72, pressure * 0.35)
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
                minutes = timeToFull
            } else {
                minutes = timeToEmpty
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
        let output = runCommand("/bin/ps", arguments: ["-A", "-o", "pid=,%cpu=,rss=,comm="])
        guard !output.isEmpty else { return ([], [], []) }

        let runningApps = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap { app -> (Int32, String)? in
                guard app.processIdentifier > 0, let name = app.localizedName, !name.isEmpty else { return nil }
                if app.activationPolicy == .regular || app.activationPolicy == .accessory {
                    return (app.processIdentifier, name)
                }
                return nil
            }
        )

        var rows: [ProcessConsumer] = []
        rows.reserveCapacity(96)

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

        let topCPU = rows
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(6)
        let topMemory = rows
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(6)
        let topBattery = rows
            .sorted { $0.batteryImpactScore > $1.batteryImpactScore }
            .prefix(6)

        return (Array(topCPU), Array(topMemory), Array(topBattery))
    }

    private func normalizedProcessName(_ commandPath: String) -> String {
        let url = URL(fileURLWithPath: commandPath)
        var name = url.lastPathComponent
        if name.isEmpty { return "" }
        if name.hasSuffix(".app") {
            name = String(name.dropLast(4))
        }
        return name
    }

    private func runCommand(_ launchPath: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "" }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self)
        } catch {
            return ""
        }
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
