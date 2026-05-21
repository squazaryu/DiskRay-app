import Foundation
import Testing
@testable import DRay

struct NetworkLatencyProbeServiceTests {
    @Test
    func parsesPacketLossAndAverageLatency() {
        let output = """
        --- 1.1.1.1 ping statistics ---
        3 packets transmitted, 2 packets received, 33.3% packet loss
        round-trip min/avg/max/stddev = 12.100/14.250/18.600/1.100 ms
        """

        #expect(NetworkLatencyProbeService.extractPacketLossPercent(from: output) == 33.3)
        #expect(NetworkLatencyProbeService.extractAverageLatencyMs(from: output) == 14.25)
    }

    @Test
    func failedPingOutputProducesErrorWithoutNetworkCall() async {
        let service = NetworkLatencyProbeService(
            commandRunner: SystemCommandRunner { _ in
                SystemCommandResult(
                    exitCode: 68,
                    stdout: "",
                    stderr: "ping: cannot resolve invalid.host: Unknown host",
                    timedOut: false,
                    wasCancelled: false
                )
            }
        )

        let samples = await service.probe(targets: [
            NetworkLatencyProbeTarget(host: "invalid.host", label: "Invalid")
        ])

        #expect(samples.count == 1)
        #expect(samples[0].averageLatencyMs == nil)
        #expect(samples[0].packetLossPercent == nil)
        #expect(samples[0].errorMessage?.contains("cannot resolve") == true)
    }
}
