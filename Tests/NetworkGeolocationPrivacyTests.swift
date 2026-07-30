import Foundation
import Testing
@testable import DRay

@Suite("NetworkGeolocationPrivacyTests")
struct NetworkGeolocationPrivacyTests {
    @Test @MainActor
    func disabledMonitorPerformsNoResolverRequests() async {
        let resolver = FakeNetworkGeolocationResolver()
        let monitor = NetworkGeolocationMonitor(resolver: resolver)

        monitor.start()
        monitor.refreshPublicProfile(force: true)
        monitor.refreshEndpoints(hosts: ["8.8.8.8", "example.com"])
        try? await Task.sleep(for: .milliseconds(20))

        let counts = await resolver.counts()
        #expect(counts.publicProfile == 0)
        #expect(counts.endpoints == 0)
        #expect(monitor.unresolvedHosts == ["8.8.8.8", "example.com"])
    }

    @Test @MainActor
    func publicProfileAndEndpointResolutionAreIndependent() async {
        let publicResolver = FakeNetworkGeolocationResolver()
        let publicMonitor = NetworkGeolocationMonitor(resolver: publicResolver)
        publicMonitor.publicProfileLookupEnabled = true
        publicMonitor.start()
        await waitUntil { publicMonitor.publicProfile != nil }

        var counts = await publicResolver.counts()
        #expect(counts.publicProfile == 1)
        #expect(counts.endpoints == 0)

        let endpointResolver = FakeNetworkGeolocationResolver()
        let endpointMonitor = NetworkGeolocationMonitor(resolver: endpointResolver)
        endpointMonitor.endpointResolutionEnabled = true
        endpointMonitor.start()
        endpointMonitor.refreshEndpoints(hosts: ["8.8.8.8"])
        await waitUntil { endpointMonitor.endpointsByHost["8.8.8.8"] != nil }

        counts = await endpointResolver.counts()
        #expect(counts.publicProfile == 0)
        #expect(counts.endpoints == 1)
    }

    @Test @MainActor
    func disablingEndpointResolutionClearsLocationsAndMarksHostsUnresolved() async {
        let resolver = FakeNetworkGeolocationResolver()
        let monitor = NetworkGeolocationMonitor(resolver: resolver)
        monitor.endpointResolutionEnabled = true
        monitor.start()
        monitor.refreshEndpoints(hosts: ["8.8.8.8"])
        await waitUntil { monitor.endpointsByHost["8.8.8.8"] != nil }

        monitor.endpointResolutionEnabled = false

        #expect(monitor.endpointsByHost.isEmpty)
        #expect(monitor.unresolvedHosts == ["8.8.8.8"])
    }

    @Test @MainActor
    func clearCacheResetsPublishedDataAndResolverCache() async {
        let resolver = FakeNetworkGeolocationResolver()
        let monitor = NetworkGeolocationMonitor(resolver: resolver)
        monitor.publicProfileLookupEnabled = true
        monitor.start()
        await waitUntil { monitor.publicProfile != nil }

        monitor.clearCache()
        await waitUntil {
            let counts = await resolver.counts()
            return counts.cacheClears == 1
        }

        #expect(monitor.publicProfile == nil)
        #expect(monitor.endpointsByHost.isEmpty)
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () async -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

private actor FakeNetworkGeolocationResolver: NetworkGeolocationResolving {
    struct RequestCounts {
        let publicProfile: Int
        let endpoints: Int
        let cacheClears: Int
    }

    private var publicProfileRequests = 0
    private var endpointRequests = 0
    private var cacheClearRequests = 0

    func resolvePublicProfile(force: Bool) -> NetworkPublicIPProfile? {
        publicProfileRequests += 1
        return NetworkPublicIPProfile(
            ip: "203.0.113.10",
            city: "Test City",
            region: "Test Region",
            countryCode: "TS",
            countryName: "Test",
            timezone: "UTC",
            organization: "AS64500 Test",
            latitude: 50,
            longitude: 30,
            updatedAt: Date()
        )
    }

    func resolveEndpoint(host: String) -> NetworkEndpointGeolocation? {
        endpointRequests += 1
        return NetworkEndpointGeolocation(
            host: host,
            ip: host,
            city: "Remote",
            region: nil,
            countryCode: "TS",
            countryName: "Test",
            organization: "AS64501 Remote",
            latitude: 51,
            longitude: 31,
            updatedAt: Date()
        )
    }

    func clearCache() {
        cacheClearRequests += 1
    }

    func counts() -> RequestCounts {
        RequestCounts(
            publicProfile: publicProfileRequests,
            endpoints: endpointRequests,
            cacheClears: cacheClearRequests
        )
    }
}
