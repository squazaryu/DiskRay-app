import Foundation

protocol EnergyConsumersProviding: Sendable {
    func fetchEnergyConsumers(now: Date) async -> [EnergyConsumerSnapshot]
}

actor EnergyConsumersService: EnergyConsumersProviding {
    private struct ProcessSample {
        let pid: Int32
        let displayName: String
        let cpuPercent: Double
        let memoryMB: Double
    }

    private struct HistoryPoint {
        let timestamp: Date
        let impact: Double
    }

    typealias CommandRunner = @Sendable (_ launchPath: String, _ arguments: [String]) -> String

    private let commandRunner: CommandRunner
    private let historyWindow: TimeInterval = 12 * 60 * 60
    private let averageWindow: TimeInterval = 20 * 60
    private let fetchCacheTTL: TimeInterval = 2.0
    private var historyByProcess: [String: [HistoryPoint]] = [:]
    private var cachedFetch: (timestamp: Date, snapshots: [EnergyConsumerSnapshot])?
    private var inFlightFetch: Task<[EnergyConsumerSnapshot], Never>?

    init(commandRunner: @escaping CommandRunner = EnergyConsumersService.defaultCommandRunner) {
        self.commandRunner = commandRunner
    }

    func fetchEnergyConsumers(now: Date = Date()) async -> [EnergyConsumerSnapshot] {
        if let cachedFetch, now.timeIntervalSince(cachedFetch.timestamp) <= fetchCacheTTL {
            return cachedFetch.snapshots
        }

        if let inFlightFetch {
            return await inFlightFetch.value
        }

        let task = Task { [weak self] in
            guard let self else { return [EnergyConsumerSnapshot]() }
            return await self.computeFreshSnapshots(now: now)
        }
        inFlightFetch = task
        let snapshots = await task.value
        inFlightFetch = nil
        cachedFetch = (timestamp: Date(), snapshots: snapshots)
        return snapshots
    }

    private func computeFreshSnapshots(now: Date) async -> [EnergyConsumerSnapshot] {
        let processSamples = readProcessSamples()
        guard !processSamples.isEmpty else {
            trimHistory(now: now)
            return []
        }

        let sleepBlockingPIDs = readSleepBlockingPIDs()
        let grouped = aggregateByName(processSamples)
        var snapshots: [EnergyConsumerSnapshot] = []
        snapshots.reserveCapacity(grouped.count)

        for sample in grouped {
            let key = sample.displayName.lowercased()
            let currentImpact = estimatedEnergyImpact(cpuPercent: sample.cpuPercent, memoryMB: sample.memoryMB)

            var history = historyByProcess[key] ?? []
            history.append(HistoryPoint(timestamp: now, impact: currentImpact))
            history.removeAll { now.timeIntervalSince($0.timestamp) > historyWindow }
            historyByProcess[key] = history

            let averageImpact = rollingAverageImpact(history: history, now: now)
            snapshots.append(
                EnergyConsumerSnapshot(
                    id: "\(key)-\(sample.pid)",
                    pid: sample.pid,
                    displayName: sample.displayName,
                    currentEnergyImpact: currentImpact,
                    averageEnergyImpact: averageImpact,
                    estimatedDrainShare: 0,
                    estimatedPower12hWh: nil,
                    preventingSleep: sleepBlockingPIDs.contains(sample.pid),
                    highPowerGPUUsage: nil,
                    appNapStatus: nil,
                    cpuPercent: sample.cpuPercent,
                    memoryMB: sample.memoryMB
                )
            )
        }

        trimHistory(now: now)
        return snapshots.sorted { lhs, rhs in
            if lhs.currentEnergyImpact != rhs.currentEnergyImpact {
                return lhs.currentEnergyImpact > rhs.currentEnergyImpact
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
    }

    private func trimHistory(now: Date) {
        historyByProcess = historyByProcess.compactMapValues { points in
            let filtered = points.filter { now.timeIntervalSince($0.timestamp) <= historyWindow }
            return filtered.isEmpty ? nil : filtered
        }
    }

    private func rollingAverageImpact(history: [HistoryPoint], now: Date) -> Double {
        let recent = history.filter { now.timeIntervalSince($0.timestamp) <= averageWindow }
        let source = recent.isEmpty ? history : recent
        guard !source.isEmpty else { return 0 }
        let sum = source.reduce(0.0) { $0 + $1.impact }
        return sum / Double(source.count)
    }

    private func estimatedEnergyImpact(cpuPercent: Double, memoryMB: Double) -> Double {
        // Not an official macOS "Energy Impact" metric. This is an internal estimate
        // used only for relative comparison in DRay.
        max(0, cpuPercent * 1.65 + memoryMB * 0.018)
    }

    private func aggregateByName(_ rows: [ProcessSample]) -> [ProcessSample] {
        var aggregated: [String: ProcessSample] = [:]
        for row in rows {
            let key = row.displayName.lowercased()
            if let existing = aggregated[key] {
                aggregated[key] = ProcessSample(
                    pid: existing.pid,
                    displayName: existing.displayName,
                    cpuPercent: existing.cpuPercent + row.cpuPercent,
                    memoryMB: existing.memoryMB + row.memoryMB
                )
            } else {
                aggregated[key] = row
            }
        }
        return Array(aggregated.values)
    }

    private func readProcessSamples() -> [ProcessSample] {
        let output = commandRunner("/bin/ps", ["-A", "-o", "pid=,%cpu=,rss=,comm="])
        guard !output.isEmpty else { return [] }

        var rows: [ProcessSample] = []
        rows.reserveCapacity(128)

        for line in output.split(separator: "\n") {
            let parts = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Double(parts[2]),
                  cpu >= 0 else {
                continue
            }

            let rawCommand = String(parts[3])
            let displayName = normalizedProcessName(rawCommand)
            guard !displayName.isEmpty else { continue }

            rows.append(
                ProcessSample(
                    pid: pid,
                    displayName: displayName,
                    cpuPercent: cpu,
                    memoryMB: rssKB / 1024.0
                )
            )
        }

        return rows
    }

    private func readSleepBlockingPIDs() -> Set<Int32> {
        let output = commandRunner("/usr/bin/pmset", ["-g", "assertions"])
        guard !output.isEmpty else { return [] }

        var pids = Set<Int32>()
        let lines = output.split(separator: "\n").map(String.init)
        for line in lines {
            guard line.contains("pid "), line.contains("):"), line.contains("Prevent") || line.contains("NoIdleSleepAssertion") else {
                continue
            }
            guard let pid = parsePID(fromAssertionLine: line) else { continue }
            pids.insert(pid)
        }
        return pids
    }

    private func parsePID(fromAssertionLine line: String) -> Int32? {
        // Example:
        // "pid 402(coreaudiod): [0x...] PreventUserIdleSystemSleep named: ..."
        guard let pidRange = line.range(of: "pid ") else { return nil }
        let rest = line[pidRange.upperBound...]
        let digits = rest.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return Int32(String(digits))
    }

    private func normalizedProcessName(_ raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        if raw.contains("/") {
            let last = URL(fileURLWithPath: raw).lastPathComponent
            if last.hasSuffix(".app") {
                return String(last.dropLast(4))
            }
            return last
        }
        if raw.hasSuffix(".app") {
            return String(raw.dropLast(4))
        }
        return raw
    }

    nonisolated private static func defaultCommandRunner(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
