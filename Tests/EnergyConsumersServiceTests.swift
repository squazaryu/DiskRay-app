import Foundation
import Testing
@testable import DRay

struct EnergyConsumersServiceTests {
    @Test
    func fetchUsesShortLivedCache() async {
        let counter = CommandCounter()
        let service = EnergyConsumersService(commandRunner: counter.runner)
        let base = Date()

        let first = await service.fetchEnergyConsumers(now: base)
        let second = await service.fetchEnergyConsumers(now: base.addingTimeInterval(1.0))

        #expect(!first.isEmpty)
        #expect(second.count == first.count)
        #expect(counter.psCount == 1)
        #expect(counter.pmsetCount == 1)
    }

    @Test
    func fetchRefreshesAfterTTL() async {
        let counter = CommandCounter()
        let service = EnergyConsumersService(commandRunner: counter.runner)
        let base = Date()

        _ = await service.fetchEnergyConsumers(now: base)
        _ = await service.fetchEnergyConsumers(now: base.addingTimeInterval(2.2))

        #expect(counter.psCount == 2)
        #expect(counter.pmsetCount == 2)
    }

    @Test
    func concurrentCallsReuseInFlightFetch() async {
        let counter = CommandCounter(simulatedCommandDelay: 0.05)
        let service = EnergyConsumersService(commandRunner: counter.runner)
        let base = Date()

        async let first = service.fetchEnergyConsumers(now: base)
        async let second = service.fetchEnergyConsumers(now: base.addingTimeInterval(0.05))

        let (a, b) = await (first, second)

        #expect(!a.isEmpty)
        #expect(b.count == a.count)
        #expect(counter.psCount == 1)
        #expect(counter.pmsetCount == 1)
    }
}

private final class CommandCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _psCount = 0
    private var _pmsetCount = 0
    private let simulatedCommandDelay: TimeInterval

    init(simulatedCommandDelay: TimeInterval = 0) {
        self.simulatedCommandDelay = simulatedCommandDelay
    }

    var runner: @Sendable (String, [String]) -> String {
        { [self] launchPath, _ in
            if simulatedCommandDelay > 0 {
                Thread.sleep(forTimeInterval: simulatedCommandDelay)
            }
            if launchPath == "/bin/ps" {
                incrementPS()
                return """
                  101 12.0 204800 /Applications/DRay.app/Contents/MacOS/DRay
                  202 3.5 51200 /usr/libexec/coreaudiod
                """
            }
            if launchPath == "/usr/bin/pmset" {
                incrementPMSet()
                return "pid 101(DRay): [0x000] PreventUserIdleSystemSleep named: \"DRay Work\""
            }
            return ""
        }
    }

    private func incrementPS() {
        lock.lock()
        _psCount += 1
        lock.unlock()
    }

    private func incrementPMSet() {
        lock.lock()
        _pmsetCount += 1
        lock.unlock()
    }

    var psCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _psCount
    }

    var pmsetCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _pmsetCount
    }
}
