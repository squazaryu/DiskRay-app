import Foundation
import Testing
@testable import DRay

struct SearchPresetUseCaseTests {
    @Test
    func loadPresetsMigratesLegacyDefaultsBlob() throws {
        let tempDir = try makeTemporaryDirectory()
        let suiteName = "SearchPresetUseCaseTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let legacyPreset = makePreset(name: "Legacy")
        let legacyKey = "dray.search.presets"
        userDefaults.set(try JSONEncoder().encode([legacyPreset]), forKey: legacyKey)

        let historyStore = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: userDefaults,
            directoryURL: tempDir
        )
        let useCase = SearchPresetUseCase(
            store: SearchPresetStore(historyStore: historyStore)
        )

        let loaded = useCase.loadPresets()

        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Legacy")
        #expect(userDefaults.data(forKey: legacyKey) == nil)
    }

    @Test
    func savePresetPrependsAndPersists() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let useCase = SearchPresetUseCase(
            store: SearchPresetStore(
                historyStore: OperationalHistoryStore(directoryURL: tempDir)
            )
        )
        let existing = [makePreset(name: "Older")]
        let draft = SearchPresetDraft(
            query: "dray",
            minSizeMB: 12,
            pathContains: "/Users",
            ownerContains: "tester",
            onlyDirectories: false,
            onlyFiles: true,
            useRegex: true,
            depthMin: 1,
            depthMax: 5,
            modifiedWithinDays: 30,
            nodeType: .file,
            searchMode: .live
        )

        let updated = useCase.savePreset(named: "New", draft: draft, in: existing)
        let loaded = useCase.loadPresets()

        #expect(updated.count == 2)
        #expect(updated.first?.name == "New")
        #expect(updated.first?.query == "dray")
        #expect(updated.first?.onlyFiles == true)
        #expect(updated.first?.useRegex == true)
        #expect(updated.first?.depthMin == 1)
        #expect(updated.first?.depthMax == 5)
        #expect(loaded.first?.name == "New")
    }

    @Test
    func deletePresetRemovesItemAndPersists() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let useCase = SearchPresetUseCase(
            store: SearchPresetStore(
                historyStore: OperationalHistoryStore(directoryURL: tempDir)
            )
        )
        let keep = useCase.savePreset(
            named: "Keep",
            draft: makeDraft(name: "Keep"),
            in: []
        )
        let withRemovable = useCase.savePreset(
            named: "Remove",
            draft: makeDraft(name: "Remove"),
            in: keep
        )
        let removablePreset = withRemovable.first { $0.name == "Remove" }
        #expect(removablePreset != nil)

        let updated = useCase.deletePreset(removablePreset!, from: withRemovable)
        let loadedAfterDelete = useCase.loadPresets()

        #expect(updated.count == 1)
        #expect(updated.first?.name == "Keep")
        #expect(loadedAfterDelete.count == 1)
        #expect(loadedAfterDelete.first?.name == "Keep")
    }

    @Test
    func applyPresetMapsValuesAndForcesLiveMode() {
        let useCase = SearchPresetUseCase(
            store: SearchPresetStore(
                historyStore: OperationalHistoryStore(directoryURL: FileManager.default.temporaryDirectory)
            )
        )
        let preset = SearchPreset(
            id: UUID(),
            name: "Saved",
            query: "needle",
            minSizeMB: 42,
            pathContains: "/Applications",
            ownerContains: "root",
            onlyDirectories: true,
            onlyFiles: false,
            useRegex: false,
            depthMin: 2,
            depthMax: 7,
            modifiedWithinDays: nil,
            nodeType: .directory,
            searchMode: .live
        )

        let applied = useCase.apply(preset)

        #expect(applied.query == "needle")
        #expect(applied.minSizeMB == 42)
        #expect(applied.onlyDirectories == true)
        #expect(applied.depthMin == 2)
        #expect(applied.depthMax == 7)
        #expect(applied.modifiedWithinDays == 0)
        #expect(applied.searchMode == .live)
    }

    private func makePreset(name: String) -> SearchPreset {
        SearchPreset(
            id: UUID(),
            name: name,
            query: "query-\(name)",
            minSizeMB: 1,
            pathContains: "/tmp",
            ownerContains: "",
            onlyDirectories: false,
            onlyFiles: true,
            useRegex: false,
            depthMin: 0,
            depthMax: 12,
            modifiedWithinDays: nil,
            nodeType: .any,
            searchMode: .live
        )
    }

    private func makeDraft(name: String) -> SearchPresetDraft {
        SearchPresetDraft(
            query: "query-\(name)",
            minSizeMB: 1,
            pathContains: "/tmp",
            ownerContains: "",
            onlyDirectories: false,
            onlyFiles: true,
            useRegex: false,
            depthMin: 0,
            depthMax: 12,
            modifiedWithinDays: nil,
            nodeType: .any,
            searchMode: .live
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-search-presets-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
