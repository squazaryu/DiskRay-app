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
    private let commandRunner: SystemCommandRunner

    init(commandRunner: SystemCommandRunner = .live) {
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
        guard Self.isValidHost(normalizedHost) else {
            return NetworkPortScanSummary(
                host: normalizedHost,
                startPort: startPort,
                endPort: endPort,
                scannedCount: 0,
                openPorts: [],
                measuredAt: Date(),
                durationSeconds: 0,
                errorMessage: "Host is invalid."
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
                    let isOpen = await Self.scanSinglePort(
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
                        let open = await Self.scanSinglePort(
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
        runner: SystemCommandRunner,
        host: String,
        port: Int,
        timeoutSeconds: Int
    ) async -> Bool {
        let result = await runner.run(
            executablePath: "/usr/bin/nc",
            arguments: ["-z", "-w", String(timeoutSeconds), host, String(port)],
            timeoutSeconds: Double(timeoutSeconds + 1)
        )
        return result.succeeded
    }

    nonisolated private static func isValidHost(_ host: String) -> Bool {
        guard host.count <= 253 else { return false }
        guard !host.contains(where: { $0.isWhitespace }) else { return false }
        guard !host.hasPrefix("-"), !host.hasSuffix("-") else { return false }
        return host.allSatisfy { character in
            character.isLetter || character.isNumber || character == "." || character == "-" || character == ":"
        }
    }
}
