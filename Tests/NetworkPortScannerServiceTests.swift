import Foundation
import Testing
@testable import DRay

struct NetworkPortScannerServiceTests {
    @Test
    func rejectsInvalidHost() async {
        let service = NetworkPortScannerService(commandRunner: fakeRunner(openPorts: []))

        let result = await service.scan(host: "bad host", startPort: 80, endPort: 80)

        #expect(result.scannedCount == 0)
        #expect(result.errorMessage == "Host is invalid.")
    }

    @Test
    func rejectsInvalidPortRange() async {
        let service = NetworkPortScannerService(commandRunner: fakeRunner(openPorts: []))

        let result = await service.scan(host: "localhost", startPort: 9000, endPort: 80)

        #expect(result.scannedCount == 0)
        #expect(result.errorMessage == "Port range is invalid.")
    }

    @Test
    func reportsFakeOpenPortsThroughInjectedRunner() async {
        let service = NetworkPortScannerService(commandRunner: fakeRunner(openPorts: [80, 443]))

        let result = await service.scan(
            host: "example.com",
            startPort: 79,
            endPort: 81,
            timeoutSeconds: 1,
            maxConcurrent: 2
        )

        #expect(result.errorMessage == nil)
        #expect(result.scannedCount == 3)
        #expect(result.openPorts == [80])
    }

    private func fakeRunner(openPorts: Set<Int>) -> SystemCommandRunner {
        SystemCommandRunner { request in
            let port = request.arguments.last.flatMap(Int.init) ?? -1
            return SystemCommandResult(
                exitCode: openPorts.contains(port) ? 0 : 1,
                stdout: "",
                stderr: "",
                timedOut: false,
                wasCancelled: false
            )
        }
    }
}
