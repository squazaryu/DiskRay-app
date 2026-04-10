import Foundation
import Testing
@testable import DRay

@MainActor
struct SearchFeatureControllerTests {
    @Test
    func saveApplyDeletePresetFlowPersistsState() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let controller = SearchFeatureController(
            selectedTargetURL: tempDir,
            liveSearchService: LiveSearchService(),
            searchPresetUseCase: SearchPresetUseCase(
                store: SearchPresetStore(
                    historyStore: OperationalHistoryStore(directoryURL: tempDir)
                )
            )
        )

        controller.update(\.query, value: "needle")
        controller.update(\.minSizeMB, value: 12)
        controller.update(\.pathContains, value: "/Users")
        controller.update(\.ownerContains, value: "tester")
        controller.update(\.onlyFiles, value: true)
        controller.update(\.depthMin, value: 1)
        controller.update(\.depthMax, value: 5)
        controller.savePreset(name: "Test preset")

        #expect(controller.state.presets.count == 1)
        let preset = try #require(controller.state.presets.first)
        #expect(preset.name == "Test preset")

        controller.update(\.query, value: "")
        controller.applyPreset(id: preset.id)
        #expect(controller.state.query == "needle")
        #expect(controller.state.minSizeMB == 12)
        #expect(controller.state.depthMin == 1)
        #expect(controller.state.depthMax == 5)

        controller.deletePreset(id: preset.id)
        #expect(controller.state.presets.isEmpty)
    }

    @Test
    func runSearchFindsMatchingFile() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetFile = tempDir.appendingPathComponent("dray-target-file.txt")
        try "sample".write(to: targetFile, atomically: true, encoding: .utf8)

        let controller = SearchFeatureController(
            selectedTargetURL: tempDir,
            liveSearchService: LiveSearchService(),
            searchPresetUseCase: SearchPresetUseCase(
                store: SearchPresetStore(
                    historyStore: OperationalHistoryStore(directoryURL: tempDir)
                )
            )
        )

        controller.update(\.query, value: "dray-target-file")
        controller.update(\.scopeMode, value: .selectedTarget)
        controller.runSearch()

        let timeout = Date().addingTimeInterval(3)
        while controller.state.isLiveRunning, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(controller.state.isLiveRunning == false)
        #expect(controller.state.results.contains { $0.name == "dray-target-file.txt" })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-search-controller-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
