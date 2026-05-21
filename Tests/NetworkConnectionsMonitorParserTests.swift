import Foundation
import Testing
@testable import DRay

struct NetworkConnectionsMonitorParserTests {
    @Test
    func parsesTcpAndUdpEndpoints() {
        let stdout = """
        Safari.123
        tcp4 10.0.0.2:51522<->93.184.216.34:443,en0,established,120,300
        mDNSResponder.77
        udp4 10.0.0.2:5353<->224.0.0.251:5353,en0,active,10,20
        """

        let snapshot = NetworkConnectionsMonitor.parseSnapshot(
            stdout: stdout,
            sampledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(snapshot.totalConnections == 2)
        #expect(snapshot.tcpConnections == 1)
        #expect(snapshot.udpConnections == 1)
        #expect(snapshot.topHosts.contains { $0.host == "93.184.216.34" })
        #expect(snapshot.topServices.contains { $0.id == "tcp:443" })
        #expect(snapshot.topServices.contains { $0.id == "udp:5353" })
        #expect(snapshot.topPrograms.contains { $0.program == "Safari" })
    }

    @Test
    func ignoresListenConnections() {
        let stdout = """
        nginx.42
        tcp4 *:8080<->*:*,,listen,0,0
        """

        let snapshot = NetworkConnectionsMonitor.parseSnapshot(
            stdout: stdout,
            sampledAt: Date()
        )

        #expect(snapshot.totalConnections == 0)
        #expect(snapshot.topHosts.isEmpty)
        #expect(snapshot.topServices.isEmpty)
    }

    @Test
    func localReservedIpDoesNotTakeGeolocationPriority() {
        let stdout = """
        DRay.900
        tcp4 10.0.0.2:51522<->192.168.1.1:443,en0,established,9000,1000
        tcp4 10.0.0.2:51523<->8.8.8.8:53,en0,established,1,1
        """

        let snapshot = NetworkConnectionsMonitor.parseSnapshot(
            stdout: stdout,
            sampledAt: Date()
        )

        #expect(NetworkConnectionsMonitor.isLikelyGeolocatableHost("192.168.1.1") == false)
        #expect(NetworkConnectionsMonitor.isLikelyGeolocatableHost("8.8.8.8"))
        #expect(snapshot.topHosts.first?.host == "8.8.8.8")
    }

    @Test
    func normalizesProgramNameByDroppingPidSuffix() {
        #expect(NetworkConnectionsMonitor.normalizedProgramName("Telegram.12345") == "Telegram")
        #expect(NetworkConnectionsMonitor.normalizedProgramName("WindowServer") == "WindowServer")
    }
}
