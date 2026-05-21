import Foundation

struct NetworkHostTraffic: Identifiable, Sendable {
    let host: String
    let bytesIn: UInt64
    let bytesOut: UInt64

    var id: String { host }
    var totalBytes: UInt64 { bytesIn + bytesOut }
}

struct NetworkServiceTraffic: Identifiable, Sendable {
    let id: String
    let label: String
    let protocolLabel: String
    let portLabel: String
    let bytesIn: UInt64
    let bytesOut: UInt64

    var totalBytes: UInt64 { bytesIn + bytesOut }
}

struct NetworkProgramTraffic: Identifiable, Sendable {
    let id: String
    let program: String
    let connectionCount: Int
    let tcpConnections: Int
    let udpConnections: Int
    let bytesIn: UInt64
    let bytesOut: UInt64

    var totalBytes: UInt64 { bytesIn + bytesOut }
}

struct NetworkConnectionsSnapshot: Sendable {
    let collectedAt: Date
    let totalConnections: Int
    let tcpConnections: Int
    let udpConnections: Int
    let activePrograms: Int
    let topHosts: [NetworkHostTraffic]
    let topServices: [NetworkServiceTraffic]
    let topPrograms: [NetworkProgramTraffic]
    let hostToServices: [String: [String]]
    let hostToPrograms: [String: [String]]
    let serviceToHosts: [String: [String]]
    let serviceToPrograms: [String: [String]]
    let programToHosts: [String: [String]]
    let programToServices: [String: [String]]
    let sampleError: String?

    static let empty = NetworkConnectionsSnapshot(
        collectedAt: .distantPast,
        totalConnections: 0,
        tcpConnections: 0,
        udpConnections: 0,
        activePrograms: 0,
        topHosts: [],
        topServices: [],
        topPrograms: [],
        hostToServices: [:],
        hostToPrograms: [:],
        serviceToHosts: [:],
        serviceToPrograms: [:],
        programToHosts: [:],
        programToServices: [:],
        sampleError: nil
    )
}

@MainActor
final class NetworkConnectionsMonitor: ObservableObject {
    @Published private(set) var snapshot: NetworkConnectionsSnapshot = .empty

    private let sampleInterval: TimeInterval
    private let commandRunner: SystemCommandRunner
    private var timer: Timer?
    private var sampleTask: Task<Void, Never>?

    init(
        sampleInterval: TimeInterval = 2.2,
        commandRunner: SystemCommandRunner = .live
    ) {
        self.sampleInterval = max(1.0, sampleInterval)
        self.commandRunner = commandRunner
    }

    func start() {
        guard timer == nil else { return }
        refreshNow()
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        sampleTask?.cancel()
        sampleTask = nil
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        sampleTask?.cancel()
        sampleTask = Task { [commandRunner] in
            let sampled = await Self.collectSnapshot(commandRunner: commandRunner)
            guard !Task.isCancelled else { return }
            snapshot = sampled
        }
    }

    nonisolated static func collectSnapshot(commandRunner: SystemCommandRunner) async -> NetworkConnectionsSnapshot {
        let now = Date()
        let run = await commandRunner.run(
            executablePath: "/usr/bin/nettop",
            arguments: ["-L", "1", "-n", "-J", "interface,state,bytes_in,bytes_out"],
            timeoutSeconds: 6
        )

        guard run.succeeded else {
            let message = run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackMessage: String
            if run.timedOut {
                fallbackMessage = "nettop timed out"
            } else if run.wasCancelled {
                fallbackMessage = "nettop cancelled"
            } else {
                fallbackMessage = "nettop failed (\(run.exitCode))"
            }
            return NetworkConnectionsSnapshot(
                collectedAt: now,
                totalConnections: 0,
                tcpConnections: 0,
                udpConnections: 0,
                activePrograms: 0,
                topHosts: [],
                topServices: [],
                topPrograms: [],
                hostToServices: [:],
                hostToPrograms: [:],
                serviceToHosts: [:],
                serviceToPrograms: [:],
                programToHosts: [:],
                programToServices: [:],
                sampleError: message.isEmpty ? fallbackMessage : message
            )
        }

        return parseSnapshot(stdout: run.stdout, sampledAt: now)
    }

    nonisolated static func parseSnapshot(stdout: String, sampledAt: Date) -> NetworkConnectionsSnapshot {
        var currentProgram = "Unknown"
        var tcpConnections = 0
        var udpConnections = 0

        var hostTraffic: [String: TrafficAccumulator] = [:]
        var serviceTraffic: [String: ServiceAccumulator] = [:]
        var programTraffic: [String: ProgramAccumulator] = [:]
        var hostToServices: [String: Set<String>] = [:]
        var hostToPrograms: [String: Set<String>] = [:]
        var serviceToHosts: [String: Set<String>] = [:]
        var serviceToPrograms: [String: Set<String>] = [:]
        var programToHosts: [String: Set<String>] = [:]
        var programToServices: [String: Set<String>] = [:]

        let lines = stdout.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard let rawDescriptor = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }
            if rawDescriptor.isEmpty || rawDescriptor == "time" {
                continue
            }

            if isConnectionDescriptor(rawDescriptor) {
                guard let parsed = parseConnectionDescriptor(rawDescriptor) else { continue }

                let interfaceName = columns.value(at: 1).trimmingCharacters(in: .whitespacesAndNewlines)
                let state = columns.value(at: 2).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let bytesIn = parseUInt(columns.value(at: 3))
                let bytesOut = parseUInt(columns.value(at: 4))

                if state == "listen" {
                    continue
                }
                if parsed.remote.host == "*", parsed.remote.port == "*", bytesIn == 0, bytesOut == 0 {
                    continue
                }
                if interfaceName.isEmpty, bytesIn == 0, bytesOut == 0 {
                    continue
                }

                switch parsed.transport {
                case .tcp:
                    tcpConnections += 1
                case .udp:
                    udpConnections += 1
                }

                var program = programTraffic[currentProgram] ?? ProgramAccumulator()
                program.bytesIn += bytesIn
                program.bytesOut += bytesOut
                program.connectionCount += 1
                if parsed.transport == .tcp {
                    program.tcpConnections += 1
                } else {
                    program.udpConnections += 1
                }
                programTraffic[currentProgram] = program

                if parsed.remote.host != "*" {
                    var host = hostTraffic[parsed.remote.host] ?? TrafficAccumulator()
                    host.bytesIn += bytesIn
                    host.bytesOut += bytesOut
                    hostTraffic[parsed.remote.host] = host
                }

                let hostID = parsed.remote.host == "*" ? nil : parsed.remote.host
                let serviceID = parsed.remote.port == "*" ? nil : "\(parsed.transport.rawValue):\(parsed.remote.port)"

                if parsed.remote.port != "*" {
                    let key = serviceID!
                    var service = serviceTraffic[key] ?? ServiceAccumulator(
                        portLabel: parsed.remote.port,
                        protocolLabel: parsed.transport.rawValue
                    )
                    service.bytesIn += bytesIn
                    service.bytesOut += bytesOut
                    serviceTraffic[key] = service
                }

                if let hostID {
                    hostToPrograms[hostID, default: []].insert(currentProgram)
                    programToHosts[currentProgram, default: []].insert(hostID)
                }
                if let serviceID {
                    serviceToPrograms[serviceID, default: []].insert(currentProgram)
                    programToServices[currentProgram, default: []].insert(serviceID)
                }
                if let hostID, let serviceID {
                    hostToServices[hostID, default: []].insert(serviceID)
                    serviceToHosts[serviceID, default: []].insert(hostID)
                }
            } else {
                let candidate = normalizedProgramName(rawDescriptor)
                if !candidate.isEmpty {
                    currentProgram = candidate
                }
            }
        }

        let hostRows = hostTraffic
            .map { host, traffic in
                NetworkHostTraffic(
                    host: host,
                    bytesIn: traffic.bytesIn,
                    bytesOut: traffic.bytesOut
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalBytes == rhs.totalBytes {
                    return lhs.host < rhs.host
                }
                return lhs.totalBytes > rhs.totalBytes
            }

        let prioritizedHostRows = hostRows.sorted { lhs, rhs in
            let lhsRemote = isLikelyGeolocatableHost(lhs.host)
            let rhsRemote = isLikelyGeolocatableHost(rhs.host)
            if lhsRemote != rhsRemote {
                return lhsRemote && !rhsRemote
            }
            if lhs.totalBytes == rhs.totalBytes {
                return lhs.host < rhs.host
            }
            return lhs.totalBytes > rhs.totalBytes
        }

        let serviceRows = serviceTraffic
            .map { key, service in
                NetworkServiceTraffic(
                    id: key,
                    label: serviceLabel(forPort: service.portLabel),
                    protocolLabel: service.protocolLabel,
                    portLabel: service.portLabel,
                    bytesIn: service.bytesIn,
                    bytesOut: service.bytesOut
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalBytes == rhs.totalBytes {
                    return lhs.id < rhs.id
                }
                return lhs.totalBytes > rhs.totalBytes
            }

        let programRows = programTraffic
            .map { name, program in
                NetworkProgramTraffic(
                    id: name,
                    program: name,
                    connectionCount: program.connectionCount,
                    tcpConnections: program.tcpConnections,
                    udpConnections: program.udpConnections,
                    bytesIn: program.bytesIn,
                    bytesOut: program.bytesOut
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalBytes == rhs.totalBytes {
                    return lhs.program < rhs.program
                }
                return lhs.totalBytes > rhs.totalBytes
            }

        let totalConnections = tcpConnections + udpConnections
        return NetworkConnectionsSnapshot(
            collectedAt: sampledAt,
            totalConnections: totalConnections,
            tcpConnections: tcpConnections,
            udpConnections: udpConnections,
            activePrograms: programRows.count,
            topHosts: Array(prioritizedHostRows.prefix(12)),
            topServices: Array(serviceRows.prefix(12)),
            topPrograms: Array(programRows.prefix(12)),
            hostToServices: sortedLinkDictionary(hostToServices),
            hostToPrograms: sortedLinkDictionary(hostToPrograms),
            serviceToHosts: sortedLinkDictionary(serviceToHosts),
            serviceToPrograms: sortedLinkDictionary(serviceToPrograms),
            programToHosts: sortedLinkDictionary(programToHosts),
            programToServices: sortedLinkDictionary(programToServices),
            sampleError: nil
        )
    }

    nonisolated private static func sortedLinkDictionary(_ input: [String: Set<String>]) -> [String: [String]] {
        input.reduce(into: [:]) { partial, item in
            partial[item.key] = item.value.sorted()
        }
    }

    nonisolated private static func isConnectionDescriptor(_ descriptor: String) -> Bool {
        descriptor.hasPrefix("tcp4 ")
        || descriptor.hasPrefix("tcp6 ")
        || descriptor.hasPrefix("udp4 ")
        || descriptor.hasPrefix("udp6 ")
    }

    nonisolated private static func parseConnectionDescriptor(_ descriptor: String) -> ParsedConnection? {
        guard let spaceIndex = descriptor.firstIndex(of: " ") else { return nil }
        let transportToken = String(descriptor[..<spaceIndex]).lowercased()
        let endpoints = String(descriptor[descriptor.index(after: spaceIndex)...])
        let parts = endpoints.components(separatedBy: "<->")
        guard parts.count == 2 else { return nil }

        let remoteEndpoint = parseEndpoint(parts[1])
        guard let transport = TransportProtocol(rawValue: transportToken.hasPrefix("tcp") ? "tcp" : "udp") else {
            return nil
        }
        return ParsedConnection(transport: transport, remote: remoteEndpoint)
    }

    nonisolated private static func parseEndpoint(_ raw: String) -> ParsedEndpoint {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedEndpoint(host: "*", port: "*")
        }
        if trimmed == "*:*" || trimmed == "*.*" || trimmed == "*" {
            return ParsedEndpoint(host: "*", port: "*")
        }

        var host = trimmed
        var port = "*"
        for index in trimmed.indices.reversed() {
            let char = trimmed[index]
            guard char == ":" || char == "." else { continue }
            let next = trimmed.index(after: index)
            guard next < trimmed.endIndex else { continue }
            let suffix = String(trimmed[next...])
            guard !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber || $0 == "*" }) else {
                continue
            }
            host = String(trimmed[..<index])
            port = suffix
            break
        }

        if let zoneIndex = host.firstIndex(of: "%") {
            host = String(host[..<zoneIndex])
        }
        if host.isEmpty {
            host = "*"
        }
        return ParsedEndpoint(host: host, port: port)
    }

    nonisolated static func normalizedProgramName(_ descriptor: String) -> String {
        let trimmed = descriptor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }
        if let dotIndex = trimmed.lastIndex(of: ".") {
            let suffix = trimmed[trimmed.index(after: dotIndex)...]
            if !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber }) {
                let name = String(trimmed[..<dotIndex])
                if !name.isEmpty {
                    return name
                }
            }
        }
        return trimmed
    }

    nonisolated static func isLikelyGeolocatableHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, normalized != "*", normalized != "localhost" else { return false }

        if let ip = normalizedIPv4Address(normalized) {
            return !isLocalOrReservedIPv4(ip)
        }

        let hasLetter = normalized.contains { $0.isLetter }
        if hasLetter {
            return true
        }
        return false
    }

    nonisolated private static func normalizedIPv4Address(_ host: String) -> String? {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }

        var normalized: [String] = []
        normalized.reserveCapacity(4)

        for octet in octets {
            let segment = String(octet)
            guard !segment.isEmpty, segment.allSatisfy(\.isNumber) else { return nil }
            guard let value = Int(segment), (0...255).contains(value) else { return nil }
            normalized.append(String(value))
        }
        return normalized.joined(separator: ".")
    }

    nonisolated private static func isLocalOrReservedIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return true }
        guard let a = Int(parts[0]), let b = Int(parts[1]) else { return true }

        if a == 10 { return true }
        if a == 127 { return true }
        if a == 169 && b == 254 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 0 { return true }
        if a >= 224 { return true }
        if a == 100 && (64...127).contains(b) { return true }
        if a == 198 && (b == 18 || b == 19) { return true }
        if a == 192 && b == 0 { return true }
        return false
    }

    nonisolated private static func parseUInt(_ value: String) -> UInt64 {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        if let direct = UInt64(trimmed) {
            return direct
        }
        if let floating = Double(trimmed) {
            return UInt64(max(0, floating.rounded()))
        }
        return 0
    }

    nonisolated private static func serviceLabel(forPort port: String) -> String {
        guard let number = Int(port) else { return ":\(port)" }
        if let known = knownServiceNames[number] {
            return known
        }
        return ":\(number)"
    }

    nonisolated private static let knownServiceNames: [Int: String] = [
        22: "ssh",
        53: "dns",
        80: "http",
        123: "ntp",
        443: "https",
        500: "isakmp",
        993: "imaps",
        995: "pop3s",
        1080: "socks",
        3306: "mysql",
        5432: "postgres",
        8080: "http-alt",
        8443: "https-alt"
    ]

}

private struct TrafficAccumulator {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
}

private struct ServiceAccumulator {
    let portLabel: String
    let protocolLabel: String
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
}

private struct ProgramAccumulator {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var connectionCount: Int = 0
    var tcpConnections: Int = 0
    var udpConnections: Int = 0
}

private enum TransportProtocol: String {
    case tcp
    case udp
}

private struct ParsedEndpoint {
    let host: String
    let port: String
}

private struct ParsedConnection {
    let transport: TransportProtocol
    let remote: ParsedEndpoint
}

private extension Array where Element == String {
    func value(at index: Int) -> String {
        guard indices.contains(index) else { return "" }
        return self[index]
    }
}
