import AppKit
import Darwin
import Foundation

private struct ProcessPriorityAdjustment {
    let pid: Int32
    let name: String
    let baselineNice: Int32
}

@MainActor
final class ProcessPriorityService: ProcessPriorityServicing {
    private var adjustments: [ProcessPriorityAdjustment] = []

    var activeAdjustmentsCount: Int {
        adjustments.count
    }

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        adjustTopConsumers(consumers.sorted { $0.cpuPercent > $1.cpuPercent }, limit: limit)
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        adjustTopConsumers(consumers.sorted { $0.memoryMB > $1.memoryMB }, limit: limit)
    }

    func restoreAdjustedPriorities(limit: Int = 5) -> LoadReliefResult {
        guard !adjustments.isEmpty else {
            return LoadReliefResult(adjusted: [], skipped: [], failed: [])
        }

        var restored: [String] = []
        var skipped: [String] = []
        var failed: [String] = []

        let maxCount = max(1, limit)
        let targets = Array(adjustments.prefix(maxCount))

        for target in targets {
            guard canAdjustPriority(forPID: target.pid) else {
                skipped.append(target.name)
                adjustments.removeAll { $0.pid == target.pid }
                continue
            }

            let niceValue = String(target.baselineNice)
            let reniceOK = runCommand(
                "/usr/bin/renice",
                arguments: [niceValue, "-p", String(target.pid)]
            )
            let policyOK = runCommand(
                "/usr/bin/taskpolicy",
                arguments: ["-B", "-p", String(target.pid)]
            )
            if reniceOK || policyOK {
                restored.append(target.name)
                adjustments.removeAll { $0.pid == target.pid }
            } else {
                failed.append(target.name)
            }
        }

        return LoadReliefResult(adjusted: restored, skipped: skipped, failed: failed)
    }

    private func adjustTopConsumers(_ consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        var adjusted: [String] = []
        var skipped: [String] = []
        var failed: [String] = []
        var processed = 0

        for consumer in consumers {
            if processed >= limit { break }
            guard canAdjustPriority(forPID: consumer.pid) else {
                skipped.append(consumer.name)
                continue
            }

            processed += 1
            let name = displayName(for: consumer)
            let baselineNice = baselineNiceValue(forPID: consumer.pid)
            let reniceOK = runCommand(
                "/usr/bin/renice",
                arguments: ["+10", "-p", String(consumer.pid)]
            )
            let backgroundOK = runCommand(
                "/usr/bin/taskpolicy",
                arguments: ["-b", "-p", String(consumer.pid)]
            )

            if reniceOK || backgroundOK {
                adjusted.append(name)
                let baseline = baselineNice ?? 0
                if let existing = adjustments.firstIndex(where: { $0.pid == consumer.pid }) {
                    adjustments[existing] = ProcessPriorityAdjustment(
                        pid: consumer.pid,
                        name: name,
                        baselineNice: adjustments[existing].baselineNice
                    )
                } else {
                    adjustments.append(
                        ProcessPriorityAdjustment(
                            pid: consumer.pid,
                            name: name,
                            baselineNice: baseline
                        )
                    )
                }
            } else {
                failed.append(name)
            }
        }

        return LoadReliefResult(adjusted: adjusted, skipped: skipped, failed: failed)
    }

    private func canAdjustPriority(forPID pid: Int32) -> Bool {
        guard pid > 1 else { return false }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return false }

        if kill(pid, 0) != 0 {
            switch errno {
            case ESRCH, EPERM:
                return false
            default:
                break
            }
        }

        if let app = NSRunningApplication(processIdentifier: pid),
           let bundleID = app.bundleIdentifier,
           bundleID.hasPrefix("com.apple.") {
            return false
        }

        return true
    }

    private func displayName(for consumer: ProcessConsumer) -> String {
        if let app = NSRunningApplication(processIdentifier: consumer.pid),
           let localized = app.localizedName,
           !localized.isEmpty {
            return localized
        }
        return consumer.name
    }

    private func baselineNiceValue(forPID pid: Int32) -> Int32? {
        errno = 0
        let value = getpriority(PRIO_PROCESS, UInt32(pid))
        if errno != 0 {
            return nil
        }
        return value
    }

    private func runCommand(_ launchPath: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
