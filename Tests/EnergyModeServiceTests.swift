import Foundation
import Testing
@testable import DRay

struct EnergyModeServiceTests {
    @Test
    func parsesCustomPowerModes() {
        let output = """
        Battery Power:
         Sleep On Power Button 1
         powermode            1
        AC Power:
         powermode            2
        """

        let parsed = EnergyModeService.parseCustomSettings(output)

        #expect(parsed.battery == .lowPower)
        #expect(parsed.charger == .highPower)
    }

    @Test
    func parsesCapabilitiesAndCurrentPowerSource() {
        let capabilities = """
        Capabilities for AC Power:
         displaysleep
         lowpowermode
         highpowermode
        """

        let parsedCapabilities = EnergyModeService.parseCapabilities(capabilities)
        let current = EnergyModeService.parseCurrentPowerSource("Now drawing from 'AC Power'")

        #expect(parsedCapabilities.lowPower)
        #expect(parsedCapabilities.highPower)
        #expect(current == .charger)
    }

    @Test
    func setEnergyModeUsesPowerSourceSpecificPmsetArguments() async {
        let spy = EnergyModeCommandSpy()
        let service = EnergyModeService(
            commandRunner: SystemCommandRunner { request in
                await spy.run(request)
            }
        )

        let result = await service.setEnergyMode(.lowPower, for: .battery)
        let requests = await spy.requests()

        #expect(result.succeeded)
        #expect(requests.contains { request in
            request.executablePath == "/usr/bin/pmset"
                && request.arguments == ["-b", "powermode", "1"]
        })
        #expect(result.settings.batteryMode == .lowPower)
        #expect(result.settings.chargerMode == .automatic)
    }

    @Test
    func failedSetReturnsReadableErrorAndRefreshesSettings() async {
        let spy = EnergyModeCommandSpy(failSet: true)
        let service = EnergyModeService(
            commandRunner: SystemCommandRunner { request in
                await spy.run(request)
            }
        )

        let result = await service.setEnergyMode(.highPower, for: .charger)

        #expect(!result.succeeded)
        #expect(result.errorMessage?.contains("pmset denied") == true)
        #expect(result.settings.batteryMode == .lowPower)
        #expect(result.settings.chargerMode == .automatic)
    }
}

private actor EnergyModeCommandSpy {
    private var capturedRequests: [SystemCommandRequest] = []
    private let failSet: Bool

    init(failSet: Bool = false) {
        self.failSet = failSet
    }

    func run(_ request: SystemCommandRequest) -> SystemCommandResult {
        capturedRequests.append(request)

        if request.arguments.count == 3, request.arguments[1] == "powermode" {
            if failSet {
                return SystemCommandResult(
                    exitCode: 1,
                    stdout: "",
                    stderr: "pmset denied",
                    timedOut: false,
                    wasCancelled: false
                )
            }
            return success("")
        }

        switch request.arguments {
        case ["-g", "custom"]:
            return success("""
            Battery Power:
             powermode            1
            AC Power:
             powermode            0
            """)
        case ["-g", "cap"]:
            return success("""
            Capabilities for AC Power:
             lowpowermode
             highpowermode
            """)
        case ["-g", "batt"]:
            return success("Now drawing from 'Battery Power'")
        default:
            return SystemCommandResult(
                exitCode: 2,
                stdout: "",
                stderr: "unexpected \(request.arguments.joined(separator: " "))",
                timedOut: false,
                wasCancelled: false
            )
        }
    }

    func requests() -> [SystemCommandRequest] {
        capturedRequests
    }

    private func success(_ stdout: String) -> SystemCommandResult {
        SystemCommandResult(
            exitCode: 0,
            stdout: stdout,
            stderr: "",
            timedOut: false,
            wasCancelled: false
        )
    }
}
