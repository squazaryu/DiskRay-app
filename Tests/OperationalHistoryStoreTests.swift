import Foundation
import Testing
@testable import DRay

struct OperationalHistoryStoreTests {
    @Test
    func saveAndLoadRoundTripFromFileStorage() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = "dray.tests.history.roundtrip.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: defaults,
            directoryURL: tempDir
        )
        let payload = [
            RecentlyDeletedItem(
                id: UUID(),
                originalPath: "/Users/test/file.txt",
                trashedPath: "/Users/test/.Trash/file.txt",
                deletedAt: Date(timeIntervalSince1970: 1_726_000_000)
            )
        ]

        store.save(payload, fileName: "recent.json")
        let loaded = store.load([RecentlyDeletedItem].self, fileName: "recent.json")

        #expect(loaded?.count == 1)
        #expect(loaded?.first?.originalPath == payload.first?.originalPath)
        #expect(loaded?.first?.trashedPath == payload.first?.trashedPath)
    }

    @Test
    func migratesLegacyUserDefaultsDataAndClearsKey() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = "dray.tests.history.migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacy = [
            SearchPreset(
                id: UUID(),
                name: "legacy",
                query: "swift",
                minSizeMB: 1,
                pathContains: "",
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
        ]
        let data = try JSONEncoder().encode(legacy)
        defaults.set(data, forKey: "legacy.presets")

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: defaults,
            directoryURL: tempDir
        )

        let loaded = store.load(
            [SearchPreset].self,
            fileName: "presets.json",
            legacyDefaultsKey: "legacy.presets"
        )

        #expect(loaded?.count == 1)
        #expect(defaults.data(forKey: "legacy.presets") == nil)

        let migratedFromFile = store.load([SearchPreset].self, fileName: "presets.json")
        #expect(migratedFromFile?.first?.name == "legacy")
    }

    @Test
    func migratesLegacyJsonFileIntoSQLiteStorage() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let legacyPayload = [
            SearchPreset(
                id: UUID(),
                name: "from-file",
                query: "legacy",
                minSizeMB: 2,
                pathContains: "/Users",
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
        ]
        let legacyFileURL = tempDir.appendingPathComponent("search-presets.json")
        try JSONEncoder().encode(legacyPayload).write(to: legacyFileURL)

        let store = OperationalHistoryStore(
            fileManager: .default,
            userDefaults: .standard,
            directoryURL: tempDir
        )

        let loaded = store.load([SearchPreset].self, fileName: "search-presets.json")
        #expect(loaded?.first?.name == "from-file")
        #expect(FileManager.default.fileExists(atPath: legacyFileURL.path) == false)

        let loadedFromSQLite = store.load([SearchPreset].self, fileName: "search-presets.json")
        #expect(loadedFromSQLite?.first?.name == "from-file")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let url = root.appendingPathComponent("dray-history-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
