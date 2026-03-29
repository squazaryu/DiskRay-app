import Foundation
import Darwin
import IOKit.ps

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
        uptimeSeconds: ProcessInfo.processInfo.systemUptime
    )
}

@MainActor
final class LiveSystemMetricsMonitor: ObservableObject {
    @Published private(set) var snapshot: LiveSystemSnapshot = .empty

    private var timer: Timer?
    private var previousCPU: CPUCounters?
    private var previousNetwork: NetworkCounters?

    func start() {
        guard timer == nil else { return }
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
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
            uptimeSeconds: ProcessInfo.processInfo.systemUptime
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
        if total > 0 {
            let compressedShare = Double(compressed) / Double(total)
            if compressedShare > 0.12 {
                pressure += min(18.0, compressedShare * 60.0)
            }
        }
        pressure = min(100, max(0, pressure))
        return (used, total, pressure)
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
            let current = desc[kIOPSCurrentCapacityKey as String] as? Int
            let max = desc[kIOPSMaxCapacityKey as String] as? Int
            let isCharging = desc[kIOPSIsChargingKey as String] as? Bool
            let timeToEmpty = desc[kIOPSTimeToEmptyKey as String] as? Int
            let timeToFull = desc[kIOPSTimeToFullChargeKey as String] as? Int

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
