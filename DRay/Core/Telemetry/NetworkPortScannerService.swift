import Foundation

struct NetworkPortScanSummary: Sendable {
    let host: String
    let startPort: Int
    let endPort: Int
    let scannedCount: Int
    let openPorts: [Int]
    let measuredAt: Date
    let durationSeconds: Double
    let errorMessage: String?
}

actor NetworkPortScannerService {
    struct CommandResult: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    typealias CommandRunner = @Sendable (_ launchPath: String, _ arguments: [String]) -> CommandResult

    private let commandRunner: CommandRunner

    init(commandRunner: @escaping CommandRunner = NetworkPortScannerService.defaultCommandRunner) {
        self.commandRunner = commandRunner
    }

    func scan(
        host: String,
        startPort: Int,
        endPort: Int,
        timeoutSeconds: Int = 1,
        maxConcurrent: Int = 24
    ) async -> NetworkPortScanSummary {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty else {
            return NetworkPortScanSummary(
                host: host,
                startPort: startPort,
                endPort: endPort,
                scannedCount: 0,
                openPorts: [],
                measuredAt: Date(),
                durationSeconds: 0,
                errorMessage: "Host is empty."
            )
        }

        guard (1...65_535).contains(startPort),
              (1...65_535).contains(endPort),
              startPort <= endPort else {
            return NetworkPortScanSummary(
                host: normalizedHost,
                startPort: startPort,
                endPort: endPort,
                scannedCount: 0,
                openPorts: [],
                measuredAt: Date(),
                durationSeconds: 0,
                errorMessage: "Port range is invalid."
            )
        }

        let ports = Array(startPort...endPort)
        let startedAt = Date()
        let runner = commandRunner
        let timeout = max(1, timeoutSeconds)
        let concurrency = max(1, min(maxConcurrent, 64))

        var iterator = ports.makeIterator()
        var openPorts: [Int] = []
        openPorts.reserveCapacity(min(ports.count, 16))

        await withTaskGroup(of: (Int, Bool).self) { group in
            for _ in 0..<min(concurrency, ports.count) {
                guard let port = iterator.next() else { break }
                group.addTask {
                    let isOpen = Self.scanSinglePort(
                        runner: runner,
                        host: normalizedHost,
                        port: port,
                        timeoutSeconds: timeout
                    )
                    return (port, isOpen)
                }
            }

            while let (port, isOpen) = await group.next() {
                if isOpen {
                    openPorts.append(port)
                }
                if let nextPort = iterator.next() {
                    group.addTask {
                        let open = Self.scanSinglePort(
                            runner: runner,
                            host: normalizedHost,
                            port: nextPort,
                            timeoutSeconds: timeout
                        )
                        return (nextPort, open)
                    }
                }
            }
        }

        openPorts.sort()
        return NetworkPortScanSummary(
            host: normalizedHost,
            startPort: startPort,
            endPort: endPort,
            scannedCount: ports.count,
            openPorts: openPorts,
            measuredAt: Date(),
            durationSeconds: Date().timeIntervalSince(startedAt),
            errorMessage: nil
        )
    }

    private nonisolated static func scanSinglePort(
        runner: CommandRunner,
        host: String,
        port: Int,
        timeoutSeconds: Int
    ) -> Bool {
        let result = runner(
            "/usr/bin/nc",
            ["-z", "-w", String(timeoutSeconds), host, String(port)]
        )
        return result.status == 0
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
        return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
