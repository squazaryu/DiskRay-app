import Foundation
import Testing
@testable import DRay

struct UninstallObservedAppsUseCaseTests {
    @Test
    func updateObservedAppsAddsCandidateWhenAppDisappearsFromInstalledList() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = "dray.tests.uninstall.observed.remove.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: defaults,
            directoryURL: tempDir
        )
        let useCase = UninstallObservedAppsUseCase(historyStore: store)

        let sampleTime = Date(timeIntervalSince1970: 1_726_000_000)
        _ = useCase.updateObservedApps(
            currentApps: [
                InstalledApp(
                    name: "Demo App",
                    bundleID: "com.example.demo",
                    appURL: URL(fileURLWithPath: "/Applications/Demo App.app")
                )
            ],
            now: sampleTime
        )

        let candidates = useCase.updateObservedApps(currentApps: [], now: sampleTime.addingTimeInterval(60))
        #expect(candidates.count == 1)
        #expect(candidates[0].appName == "Demo App")
        #expect(candidates[0].bundleID == "com.example.demo")
        #expect(candidates[0].lastKnownAppPath == "/Applications/Demo App.app")
    }

    @Test
    func updateObservedAppsRemovesCandidateWhenAppReappears() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = "dray.tests.uninstall.observed.reinstall.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: defaults,
            directoryURL: tempDir
        )
        let useCase = UninstallObservedAppsUseCase(historyStore: store)

        let app = InstalledApp(
            name: "Demo App",
            bundleID: "com.example.demo",
            appURL: URL(fileURLWithPath: "/Applications/Demo App.app")
        )

        _ = useCase.updateObservedApps(currentApps: [app], now: Date(timeIntervalSince1970: 1_726_000_000))
        _ = useCase.updateObservedApps(currentApps: [], now: Date(timeIntervalSince1970: 1_726_000_060))

        let reappeared = useCase.updateObservedApps(currentApps: [app], now: Date(timeIntervalSince1970: 1_726_000_120))
        #expect(reappeared.isEmpty)
        #expect(useCase.loadRemovedCandidates().isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let url = root.appendingPathComponent("dray-observed-app-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
