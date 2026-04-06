import Foundation
import Testing
@testable import DRay

struct SmartExclusionUseCaseTests {
    @Test
    func loadStateReadsPersistedArrays() {
        let suiteName = "SmartExclusionUseCaseTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        userDefaults.set(["/tmp/a"], forKey: "paths")
        userDefaults.set(["user_logs"], forKey: "analyzers")
        let useCase = SmartExclusionUseCase(
            userDefaults: userDefaults,
            pathsKey: "paths",
            analyzerKeysKey: "analyzers"
        )

        let state = useCase.loadState()

        #expect(state.excludedPaths == ["/tmp/a"])
        #expect(state.excludedAnalyzerKeys == ["user_logs"])
    }

    @Test
    func addPathNormalizesSortsAndAvoidsDuplicates() {
        let suiteName = "SmartExclusionUseCaseTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let useCase = SmartExclusionUseCase(
            userDefaults: userDefaults,
            pathsKey: "paths",
            analyzerKeysKey: "analyzers"
        )
        let base = ["/tmp/z", "/tmp/b"]

        let withNew = useCase.addPath("/tmp/a", to: base)
        let withDuplicate = useCase.addPath("/tmp/a", to: withNew)

        #expect(withNew == ["/tmp/a", "/tmp/b", "/tmp/z"])
        #expect(withDuplicate == withNew)
        #expect(userDefaults.stringArray(forKey: "paths") == withNew)
    }

    @Test
    func togglePathAddsAndRemoves() {
        let suiteName = "SmartExclusionUseCaseTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let useCase = SmartExclusionUseCase(
            userDefaults: userDefaults,
            pathsKey: "paths",
            analyzerKeysKey: "analyzers"
        )

        let added = useCase.togglePath("/tmp/demo", currentPaths: [])
        let removed = useCase.togglePath("/tmp/demo", currentPaths: added)

        #expect(added == ["/tmp/demo"])
        #expect(removed.isEmpty)
    }

    @Test
    func toggleAnalyzerAddsAndRemovesSorted() {
        let suiteName = "SmartExclusionUseCaseTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let useCase = SmartExclusionUseCase(
            userDefaults: userDefaults,
            pathsKey: "paths",
            analyzerKeysKey: "analyzers"
        )

        let added = useCase.toggleAnalyzer("xcode_derived_data", currentAnalyzerKeys: ["user_logs"])
        let removed = useCase.toggleAnalyzer("user_logs", currentAnalyzerKeys: added)

        #expect(added == ["user_logs", "xcode_derived_data"])
        #expect(removed == ["xcode_derived_data"])
        #expect(userDefaults.stringArray(forKey: "analyzers") == removed)
    }
}
