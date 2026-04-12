import Foundation

protocol NetworkSpeedTesting: Sendable {
    func runSpeedTest() async -> NetworkSpeedTestResult
}

actor NetworkSpeedTestService: NetworkSpeedTesting {
    struct CommandResult: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    typealias CommandRunner = @Sendable (_ launchPath: String, _ arguments: [String]) -> CommandResult

    private let commandRunner: CommandRunner
    private let maxRuntimeSeconds: Int
    private let outputDateFormatter: DateFormatter

    init(
        maxRuntimeSeconds: Int = 12,
        commandRunner: @escaping CommandRunner = NetworkSpeedTestService.defaultCommandRunner
    ) {
        self.maxRuntimeSeconds = max(5, maxRuntimeSeconds)
        self.commandRunner = commandRunner

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.outputDateFormatter = formatter
    }

    func runSpeedTest() async -> NetworkSpeedTestResult {
        let now = Date()
        let run = commandRunner(
            "/usr/bin/networkQuality",
            ["-c", "-M", String(maxRuntimeSeconds)]
        )

        guard run.status == 0 else {
            let details = run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = details.isEmpty ? "networkQuality failed with status \(run.status)" : details
            return NetworkSpeedTestResult(
                measuredAt: now,
                interfaceName: nil,
                downlinkMbps: nil,
                uplinkMbps: nil,
                responsivenessMs: nil,
                baseRTTMs: nil,
                errorMessage: message
            )
        }

        guard let data = run.stdout.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NetworkSpeedTestResult(
                measuredAt: now,
                interfaceName: nil,
                downlinkMbps: nil,
                uplinkMbps: nil,
                responsivenessMs: nil,
                baseRTTMs: nil,
                errorMessage: "Failed to decode networkQuality output"
            )
        }

        let measuredAt = (payload["end_date"] as? String)
            .flatMap { outputDateFormatter.date(from: $0) } ?? now
        let downlinkBps = doubleValue(payload["dl_throughput"])
        let uplinkBps = doubleValue(payload["ul_throughput"])

        return NetworkSpeedTestResult(
            measuredAt: measuredAt,
            interfaceName: payload["interface_name"] as? String,
            downlinkMbps: downlinkBps.map { max(0, $0 / 1_000_000.0) },
            uplinkMbps: uplinkBps.map { max(0, $0 / 1_000_000.0) },
            responsivenessMs: doubleValue(payload["responsiveness"]),
            baseRTTMs: doubleValue(payload["base_rtt"]),
            errorMessage: nil
        )
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? Int { return Double(value) }
        if let text = value as? String { return Double(text) }
        return nil
    }

    nonisolated private static func defaultCommandRunner(_ launchPath: String, _ arguments: [String]) -> CommandResult {
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
            return CommandResult(status: 1, stdout: "", stderr: error.localizedDescription)
        }

        let outputData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""

        return CommandResult(
            status: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }
}
