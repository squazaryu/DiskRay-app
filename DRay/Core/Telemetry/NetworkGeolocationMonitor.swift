import Foundation
import Darwin

struct NetworkPublicIPProfile: Sendable {
    let ip: String
    let city: String?
    let region: String?
    let countryCode: String?
    let countryName: String?
    let timezone: String?
    let organization: String?
    let latitude: Double?
    let longitude: Double?
    let updatedAt: Date

    var locationLabel: String {
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let region, !region.isEmpty { parts.append(region) }
        if let countryCode, !countryCode.isEmpty { parts.append(countryCode) }
        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }
}

struct NetworkEndpointGeolocation: Identifiable, Sendable {
    let host: String
    let ip: String
    let city: String?
    let region: String?
    let countryCode: String?
    let countryName: String?
    let organization: String?
    let latitude: Double
    let longitude: Double
    let updatedAt: Date

    var id: String { host }

    var locationLabel: String {
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let region, !region.isEmpty { parts.append(region) }
        if let countryCode, !countryCode.isEmpty { parts.append(countryCode) }
        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }
}

@MainActor
final class NetworkGeolocationMonitor: ObservableObject {
    @Published private(set) var publicProfile: NetworkPublicIPProfile?
    @Published private(set) var endpointsByHost: [String: NetworkEndpointGeolocation] = [:]
    @Published private(set) var unresolvedHosts: Set<String> = []
    @Published private(set) var lastErrorMessage: String?
    @Published var resolveEnabled = true {
        didSet {
            if resolveEnabled {
                if !lastRequestedHosts.isEmpty {
                    refreshEndpoints(hosts: Array(lastRequestedHosts))
                }
            } else {
                unresolvedHosts.removeAll()
                endpointResolutionTask?.cancel()
                endpointResolutionTask = nil
            }
        }
    }

    private let resolver: NetworkGeolocationResolver
    private var endpointResolutionTask: Task<Void, Never>?
    private var publicProfileTask: Task<Void, Never>?
    private var lastRequestedHosts: Set<String> = []

    init(resolver: NetworkGeolocationResolver = NetworkGeolocationResolver()) {
        self.resolver = resolver
    }

    func start() {
        refreshPublicProfile(force: false)
    }

    func stop() {
        endpointResolutionTask?.cancel()
        endpointResolutionTask = nil
        publicProfileTask?.cancel()
        publicProfileTask = nil
    }

    func refreshPublicProfile(force: Bool = false) {
        publicProfileTask?.cancel()
        publicProfileTask = Task { [resolver] in
            let profile = await resolver.resolvePublicProfile(force: force)
            guard !Task.isCancelled else { return }
            publicProfile = profile
            if profile == nil {
                lastErrorMessage = "Failed to resolve public IP profile."
            } else {
                lastErrorMessage = nil
            }
            publicProfileTask = nil
        }
    }

    func refreshEndpoints(hosts: [String]) {
        guard resolveEnabled else { return }

        let uniqueHosts = Set(hosts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "*" })

        if uniqueHosts.isEmpty {
            lastRequestedHosts = []
            unresolvedHosts.removeAll()
            endpointResolutionTask?.cancel()
            endpointResolutionTask = nil
            return
        }

        let requestedHostsChanged = uniqueHosts != lastRequestedHosts
        if !requestedHostsChanged {
            if endpointResolutionTask != nil {
                return
            }
            let missingHosts = uniqueHosts.filter { endpointsByHost[$0] == nil && !unresolvedHosts.contains($0) }
            if missingHosts.isEmpty {
                return
            }
        }

        lastRequestedHosts = uniqueHosts
        endpointResolutionTask?.cancel()

        let knownUnresolved = unresolvedHosts
        let hostsToResolve = uniqueHosts.filter { endpointsByHost[$0] == nil }.sorted()
        if hostsToResolve.isEmpty {
            unresolvedHosts = knownUnresolved.intersection(uniqueHosts)
            endpointResolutionTask = nil
            return
        }

        endpointResolutionTask = Task { [resolver] in
            var collected: [String: NetworkEndpointGeolocation] = [:]
            var unresolved = knownUnresolved.intersection(uniqueHosts)

            await withTaskGroup(of: (String, NetworkEndpointGeolocation?).self) { group in
                for host in hostsToResolve {
                    group.addTask {
                        let result = await resolver.resolveEndpoint(host: host)
                        return (host, result)
                    }
                }

                for await (host, result) in group {
                    if let result {
                        collected[host] = result
                    } else {
                        unresolved.insert(host)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            for (host, geo) in collected {
                endpointsByHost[host] = geo
            }
            unresolvedHosts = unresolved
            lastErrorMessage = nil
            endpointResolutionTask = nil
        }
    }
}

actor NetworkGeolocationResolver {
    private struct CacheEntry<T> {
        let value: T
        let validUntil: Date
    }

    private struct IPAPIResponse: Decodable {
        let ip: String?
        let city: String?
        let region: String?
        let country: String?
        let countryName: String?
        let timezone: String?
        let org: String?
        let latitude: Double?
        let longitude: Double?
        let error: Bool?
        let reason: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case ip
            case city
            case region
            case country
            case countryName = "country_name"
            case timezone
            case org
            case latitude
            case longitude
            case error
            case reason
            case message
        }
    }

    private struct IPInfoResponse: Decodable {
        let ip: String?
        let city: String?
        let region: String?
        let country: String?
        let location: String?
        let organization: String?
        let timezone: String?
        let bogon: Bool?

        enum CodingKeys: String, CodingKey {
            case ip
            case city
            case region
            case country
            case location = "loc"
            case organization = "org"
            case timezone
            case bogon
        }
    }

    private struct IPWhoIsResponse: Decodable {
        struct Connection: Decodable {
            let asn: Int?
            let organization: String?
            let isp: String?

            enum CodingKeys: String, CodingKey {
                case asn
                case organization = "org"
                case isp
            }
        }

        struct Timezone: Decodable {
            let id: String?
        }

        let success: Bool?
        let ip: String?
        let city: String?
        let region: String?
        let countryCode: String?
        let country: String?
        let latitude: Double?
        let longitude: Double?
        let connection: Connection?
        let timezone: Timezone?

        enum CodingKeys: String, CodingKey {
            case success
            case ip
            case city
            case region
            case countryCode = "country_code"
            case country
            case latitude
            case longitude
            case connection
            case timezone
        }
    }

    private let endpointTTL: TimeInterval
    private let publicTTL: TimeInterval
    private let session: URLSession

    private var endpointCache: [String: CacheEntry<NetworkEndpointGeolocation>] = [:]
    private var publicProfileCache: CacheEntry<NetworkPublicIPProfile>?
    private var endpointInFlight: [String: Task<NetworkEndpointGeolocation?, Never>] = [:]
    private var publicProfileInFlight: Task<NetworkPublicIPProfile?, Never>?

    init(endpointTTL: TimeInterval = 12 * 60 * 60, publicTTL: TimeInterval = 10 * 60) {
        self.endpointTTL = endpointTTL
        self.publicTTL = publicTTL

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 7
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    func resolvePublicProfile(force: Bool = false) async -> NetworkPublicIPProfile? {
        let now = Date()
        if !force, let cached = publicProfileCache, cached.validUntil > now {
            return cached.value
        }

        if let running = publicProfileInFlight {
            return await running.value
        }

        let task = Task<NetworkPublicIPProfile?, Never> { [session] in
            if let primary = await Self.fetchPublicProfileFromIPAPI(using: session) {
                return primary
            }
            if let fallback = await Self.fetchPublicProfileFromIPInfo(using: session) {
                return fallback
            }
            if let fallback = await Self.fetchPublicProfileFromIPWhoIs(using: session) {
                return fallback
            }
            if let ipOnly = await Self.fetchPublicIPAddress(using: session) {
                return NetworkPublicIPProfile(
                    ip: ipOnly,
                    city: nil,
                    region: nil,
                    countryCode: nil,
                    countryName: nil,
                    timezone: nil,
                    organization: nil,
                    latitude: nil,
                    longitude: nil,
                    updatedAt: Date()
                )
            }
            return nil
        }
        publicProfileInFlight = task
        let result = await task.value
        publicProfileInFlight = nil

        if let result {
            publicProfileCache = CacheEntry(
                value: result,
                validUntil: now.addingTimeInterval(publicTTL)
            )
        }
        return result
    }

    func resolveEndpoint(host: String) async -> NetworkEndpointGeolocation? {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let resolvedIP: String
        if let directIP = normalizedIPv4(host: normalized) {
            resolvedIP = directIP
        } else if let dnsIP = await resolveHostnameToIPv4(host: normalized) {
            resolvedIP = dnsIP
        } else {
            return nil
        }
        guard !Self.isLocalOrReservedIPv4(resolvedIP) else { return nil }

        let now = Date()
        if let cached = endpointCache[resolvedIP], cached.validUntil > now {
            return cached.value
        }
        if let running = endpointInFlight[resolvedIP] {
            return await running.value
        }

        let task = Task<NetworkEndpointGeolocation?, Never> { [session] in
            if let primary = await Self.fetchEndpointFromIPAPI(ip: resolvedIP, host: normalized, using: session) {
                return primary
            }
            if let fallback = await Self.fetchEndpointFromIPInfo(ip: resolvedIP, host: normalized, using: session) {
                return fallback
            }
            if let fallback = await Self.fetchEndpointFromIPWhoIs(ip: resolvedIP, host: normalized, using: session) {
                return fallback
            }
            return nil
        }
        endpointInFlight[resolvedIP] = task
        let result = await task.value
        endpointInFlight[resolvedIP] = nil

        if let result {
            endpointCache[resolvedIP] = CacheEntry(
                value: result,
                validUntil: now.addingTimeInterval(endpointTTL)
            )
        }
        return result
    }

    private func resolveHostnameToIPv4(host: String) async -> String? {
        await Task.detached(priority: .utility) {
            Self.resolveHostnameToIPv4Sync(host: host)
        }.value
    }

    private func normalizedIPv4(host: String) -> String? {
        Self.normalizedIPv4String(host)
    }

    private nonisolated static func normalizedIPv4String(_ host: String) -> String? {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }

        var normalized: [String] = []
        normalized.reserveCapacity(4)

        for octet in octets {
            let segment = String(octet)
            guard !segment.isEmpty else { return nil }
            guard segment.allSatisfy({ $0.isNumber }) else { return nil }
            guard let value = Int(segment), (0...255).contains(value) else { return nil }
            normalized.append(String(value))
        }

        return normalized.joined(separator: ".")
    }

    private nonisolated static func isLocalOrReservedIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return true }
        guard let a = Int(parts[0]), let b = Int(parts[1]) else { return true }

        if a == 10 { return true }
        if a == 127 { return true }
        if a == 169 && b == 254 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 0 { return true }
        if a >= 224 { return true } // multicast/reserved
        if a == 100 && (64...127).contains(b) { return true } // carrier-grade NAT
        if a == 198 && (b == 18 || b == 19) { return true } // benchmark
        if a == 192 && b == 0 { return true } // IETF protocol assignments subset
        return false
    }

    private nonisolated static func resolveHostnameToIPv4Sync(host: String) -> String? {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var resultPointer: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &resultPointer)
        guard status == 0, let head = resultPointer else { return nil }
        defer { freeaddrinfo(head) }

        var current: UnsafeMutablePointer<addrinfo>? = head
        while let node = current {
            if node.pointee.ai_family == AF_INET,
               let rawAddress = node.pointee.ai_addr {
                let sockaddr = rawAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var address = sockaddr.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                    let resolvedBytes = buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
                    let resolved = String(decoding: resolvedBytes, as: UTF8.self)
                    if normalizedIPv4String(resolved) != nil {
                        return resolved
                    }
                }
            }
            current = node.pointee.ai_next
        }
        return nil
    }

    private nonisolated static func fetchPublicProfileFromIPAPI(using session: URLSession) async -> NetworkPublicIPProfile? {
        guard let url = URL(string: "https://ipapi.co/json/") else { return nil }
        guard let payload: IPAPIResponse = await fetch(url: url, using: session) else { return nil }
        guard payload.error != true else { return nil }
        guard let ip = payload.ip, !ip.isEmpty else { return nil }

        return NetworkPublicIPProfile(
            ip: ip,
            city: payload.city,
            region: payload.region,
            countryCode: payload.country,
            countryName: payload.countryName,
            timezone: payload.timezone,
            organization: payload.org,
            latitude: payload.latitude,
            longitude: payload.longitude,
            updatedAt: Date()
        )
    }

    private nonisolated static func fetchPublicProfileFromIPInfo(using session: URLSession) async -> NetworkPublicIPProfile? {
        guard let url = URL(string: "https://ipinfo.io/json") else { return nil }
        guard let payload: IPInfoResponse = await fetch(url: url, using: session) else { return nil }
        guard payload.bogon != true else { return nil }
        guard let ip = payload.ip, !ip.isEmpty else { return nil }
        let coordinates = parseLocation(payload.location)

        return NetworkPublicIPProfile(
            ip: ip,
            city: payload.city,
            region: payload.region,
            countryCode: payload.country,
            countryName: nil,
            timezone: payload.timezone,
            organization: payload.organization,
            latitude: coordinates?.latitude,
            longitude: coordinates?.longitude,
            updatedAt: Date()
        )
    }

    private nonisolated static func fetchPublicIPAddress(using session: URLSession) async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return nil }
        guard let payload: [String: String] = await fetch(url: url, using: session) else { return nil }
        guard let ip = payload["ip"], !ip.isEmpty else { return nil }
        return ip
    }

    private nonisolated static func fetchPublicProfileFromIPWhoIs(using session: URLSession) async -> NetworkPublicIPProfile? {
        guard let url = URL(string: "https://ipwho.is/") else { return nil }
        guard let payload: IPWhoIsResponse = await fetch(url: url, using: session) else { return nil }
        guard payload.success != false else { return nil }
        guard let ip = payload.ip, !ip.isEmpty else { return nil }

        let org = payload.connection?.organization ?? payload.connection?.isp
        return NetworkPublicIPProfile(
            ip: ip,
            city: payload.city,
            region: payload.region,
            countryCode: payload.countryCode,
            countryName: payload.country,
            timezone: payload.timezone?.id,
            organization: org,
            latitude: payload.latitude,
            longitude: payload.longitude,
            updatedAt: Date()
        )
    }

    private nonisolated static func fetchEndpointFromIPAPI(
        ip: String,
        host: String,
        using session: URLSession
    ) async -> NetworkEndpointGeolocation? {
        guard let url = URL(string: "https://ipapi.co/\(ip)/json/") else { return nil }
        guard let payload: IPAPIResponse = await fetch(url: url, using: session) else { return nil }
        guard payload.error != true else { return nil }
        guard let latitude = payload.latitude, let longitude = payload.longitude else { return nil }

        return NetworkEndpointGeolocation(
            host: host,
            ip: payload.ip ?? ip,
            city: payload.city,
            region: payload.region,
            countryCode: payload.country,
            countryName: payload.countryName,
            organization: payload.org,
            latitude: latitude,
            longitude: longitude,
            updatedAt: Date()
        )
    }

    private nonisolated static func fetchEndpointFromIPInfo(
        ip: String,
        host: String,
        using session: URLSession
    ) async -> NetworkEndpointGeolocation? {
        guard let url = URL(string: "https://ipinfo.io/\(ip)/json") else { return nil }
        guard let payload: IPInfoResponse = await fetch(url: url, using: session) else { return nil }
        guard payload.bogon != true else { return nil }
        let coordinates = parseLocation(payload.location)
        guard let latitude = coordinates?.latitude, let longitude = coordinates?.longitude else { return nil }

        return NetworkEndpointGeolocation(
            host: host,
            ip: payload.ip ?? ip,
            city: payload.city,
            region: payload.region,
            countryCode: payload.country,
            countryName: nil,
            organization: payload.organization,
            latitude: latitude,
            longitude: longitude,
            updatedAt: Date()
        )
    }

    private nonisolated static func fetchEndpointFromIPWhoIs(
        ip: String,
        host: String,
        using session: URLSession
    ) async -> NetworkEndpointGeolocation? {
        guard let url = URL(string: "https://ipwho.is/\(ip)") else { return nil }
        guard let payload: IPWhoIsResponse = await fetch(url: url, using: session) else { return nil }
        guard payload.success != false else { return nil }
        guard let latitude = payload.latitude, let longitude = payload.longitude else { return nil }
        let org = payload.connection?.organization ?? payload.connection?.isp

        return NetworkEndpointGeolocation(
            host: host,
            ip: payload.ip ?? ip,
            city: payload.city,
            region: payload.region,
            countryCode: payload.countryCode,
            countryName: payload.country,
            organization: org,
            latitude: latitude,
            longitude: longitude,
            updatedAt: Date()
        )
    }

    private nonisolated static func parseLocation(_ raw: String?) -> (latitude: Double, longitude: Double)? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        guard let latitude = Double(parts[0]),
              let longitude = Double(parts[1]),
              abs(latitude) <= 90,
              abs(longitude) <= 180 else {
            return nil
        }
        return (latitude, longitude)
    }

    private nonisolated static func fetch<T: Decodable>(url: URL, using session: URLSession) async -> T? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DRay/2.1.3", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200...299).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
