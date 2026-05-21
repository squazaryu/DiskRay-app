import Foundation

struct NetworkLatencyProbeTarget: Identifiable, Hashable, Sendable {
    let host: String
    let label: String

    var id: String { host.lowercased() }
}

struct NetworkLatencyProbeSample: Identifiable, Sendable {
    let target: NetworkLatencyProbeTarget
    let averageLatencyMs: Double?
    let packetLossPercent: Double?
    let measuredAt: Date
    let errorMessage: String?

    var id: String { target.id }

    var isReachable: Bool {
        guard let packetLossPercent else { return false }
        return packetLossPercent < 100.0
    }
}

@MainActor
final class NetworkLatencyMonitor: ObservableObject {
    @Published private(set) var samples: [NetworkLatencyProbeSample] = []
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    let targets: [NetworkLatencyProbeTarget]

    private let refreshInterval: TimeInterval
    private let service: NetworkLatencyProbeService
    private var samplingTask: Task<Void, Never>?

    init(
        targets: [NetworkLatencyProbeTarget] = NetworkLatencyMonitor.defaultTargets,
        refreshInterval: TimeInterval = 1.2,
        service: NetworkLatencyProbeService = NetworkLatencyProbeService()
    ) {
        self.targets = targets
        self.refreshInterval = max(0.6, refreshInterval)
        self.service = service
    }

    func start() {
        guard samplingTask == nil else { return }
        guard !isPaused else { return }

        isRunning = true
        samplingTask = Task { [weak self] in
            guard let self else { return }
            await self.runSamplingLoop()
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        isRunning = false
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        stop()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        start()
    }

    func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            await self.sampleOnce()
        }
    }

    private func runSamplingLoop() async {
        defer {
            if !Task.isCancelled {
                isRunning = false
                samplingTask = nil
            }
        }

        while !Task.isCancelled {
            await sampleOnce()
            let pauseNanos = UInt64(refreshInterval * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: pauseNanos)
            } catch {
                break
            }
        }
    }

    private func sampleOnce() async {
        let probeSamples = await service.probe(targets: targets)
        guard !Task.isCancelled else { return }

        samples = probeSamples
        lastUpdatedAt = Date()
        lastErrorMessage = probeSamples
            .compactMap(\.errorMessage)
            .first
    }

    private static let defaultTargets: [NetworkLatencyProbeTarget] = [
        NetworkLatencyProbeTarget(host: "1.1.1.1", label: "Cloudflare"),
        NetworkLatencyProbeTarget(host: "8.8.8.8", label: "Google DNS"),
        NetworkLatencyProbeTarget(host: "apple.com", label: "apple.com"),
        NetworkLatencyProbeTarget(host: "github.com", label: "github.com")
    ]
}

actor NetworkLatencyProbeService {
    private let commandRunner: SystemCommandRunner
    private let packetsPerProbe: Int
    private let packetWaitMillis: Int

    init(
        packetsPerProbe: Int = 3,
        packetWaitMillis: Int = 800,
        commandRunner: SystemCommandRunner = .live
    ) {
        self.packetsPerProbe = max(1, packetsPerProbe)
        self.packetWaitMillis = max(100, packetWaitMillis)
        self.commandRunner = commandRunner
    }

    func probe(targets: [NetworkLatencyProbeTarget]) async -> [NetworkLatencyProbeSample] {
        let runner = commandRunner
        let countArg = String(packetsPerProbe)
        let waitArg = String(packetWaitMillis)
        let commandTimeoutSeconds = Double(max(2, (packetWaitMillis * packetsPerProbe) / 1_000 + 2))

        let measuredAt = Date()
        let order = Dictionary(uniqueKeysWithValues: targets.enumerated().map { ($0.element.id, $0.offset) })

        var rows: [NetworkLatencyProbeSample] = []
        rows.reserveCapacity(targets.count)

        await withTaskGroup(of: NetworkLatencyProbeSample.self) { group in
            for target in targets {
                group.addTask {
                    let run = await runner.run(
                        executablePath: "/sbin/ping",
                        arguments: ["-q", "-n", "-c", countArg, "-W", waitArg, target.host],
                        timeoutSeconds: commandTimeoutSeconds
                    )

                    let mergedOutput = run.stdout + "\n" + run.stderr
                    let packetLoss = Self.extractPacketLossPercent(from: mergedOutput)
                    let avgLatency = Self.extractAverageLatencyMs(from: mergedOutput)
                    let textError = run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

                    let errorMessage: String?
                    if run.succeeded || packetLoss != nil {
                        errorMessage = nil
                    } else if run.timedOut {
                        errorMessage = "Ping timed out for \(target.host)"
                    } else if run.wasCancelled {
                        errorMessage = "Ping cancelled for \(target.host)"
                    } else if !textError.isEmpty {
                        errorMessage = textError
                    } else {
                        errorMessage = "Ping failed for \(target.host) (status \(run.exitCode))"
                    }

                    return NetworkLatencyProbeSample(
                        target: target,
                        averageLatencyMs: avgLatency,
                        packetLossPercent: packetLoss,
                        measuredAt: measuredAt,
                        errorMessage: errorMessage
                    )
                }
            }

            for await row in group {
                rows.append(row)
            }
        }

        rows.sort { lhs, rhs in
            (order[lhs.id] ?? .max) < (order[rhs.id] ?? .max)
        }
        return rows
    }

    nonisolated static func extractPacketLossPercent(from output: String) -> Double? {
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.contains("% packet loss"),
                  let range = line.range(of: "% packet loss") else { continue }
            let prefix = line[..<range.lowerBound]
            guard let token = prefix
                .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .last else { continue }
            return Double(token)
        }
        return nil
    }

    nonisolated static func extractAverageLatencyMs(from output: String) -> Double? {
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.contains("min/avg/max"),
                  let equalSign = line.firstIndex(of: "=") else { continue }
            let rhs = line[line.index(after: equalSign)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let group = rhs.split(separator: " ").first else { continue }
            let values = group.split(separator: "/")
            guard values.count >= 2 else { continue }
            return Double(values[1])
        }
        return nil
    }

}
