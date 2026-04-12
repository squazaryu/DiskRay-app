import Foundation
import Testing
@testable import DRay

struct NetworkSpeedTestServiceTests {
    @Test
    func parsesNetworkQualityJsonIntoResult() async {
        let json = """
        {
          "end_date": "2026-04-12 18:07:43.822",
          "interface_name": "en0",
          "dl_throughput": 245000000,
          "ul_throughput": 41000000,
          "responsiveness": 118.4,
          "base_rtt": 32.6
        }
        """
        let service = NetworkSpeedTestService(
            commandRunner: { _, _ in
                .init(status: 0, stdout: json, stderr: "")
            }
        )

        let result = await service.runSpeedTest()

        #expect(result.errorMessage == nil)
        #expect(result.interfaceName == "en0")
        #expect(result.downlinkMbps == 245.0)
        #expect(result.uplinkMbps == 41.0)
        #expect(result.responsivenessMs == 118.4)
        #expect(result.baseRTTMs == 32.6)
    }

    @Test
    func returnsFailureWhenCommandFails() async {
        let service = NetworkSpeedTestService(
            commandRunner: { _, _ in
                .init(status: 1, stdout: "", stderr: "timeout")
            }
        )

        let result = await service.runSpeedTest()

        #expect(result.isSuccess == false)
        #expect(result.errorMessage == "timeout")
        #expect(result.downlinkMbps == nil)
        #expect(result.uplinkMbps == nil)
    }
}
