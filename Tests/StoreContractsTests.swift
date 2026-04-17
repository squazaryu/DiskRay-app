import Foundation
import Testing
@testable import DRay

@MainActor
struct StoreContractsTests {
    @Test
    func uiSettingsStoreRoundtrip() {
        let suiteName = "UISettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UISettingsStore(userDefaults: defaults)
        let bookmarkData = Data([0x01, 0x02, 0x03])

        store.saveAppLanguage(.russian)
        store.saveAppAppearance(.dark)
        store.saveDefaultScanTarget(.home)
        store.saveAutoRescanAfterCleanup(false)
        store.saveIncludeHiddenByDefault(false)
        store.saveIncludePackageContentsByDefault(false)
        store.saveExcludeTrashByDefault(true)
        store.saveDefaultSmartCareProfile(.aggressive)
        store.saveConfirmBeforeDestructiveActions(false)
        store.saveConfirmBeforeStartupCleanup(false)
        store.saveConfirmBeforeRepairFlows(true)
        store.saveAutoRescanAfterRestore(false)
        store.saveSelectedTargetBookmark(bookmarkData)

        #expect(store.loadAppLanguage() == .russian)
        #expect(store.loadAppAppearance() == .dark)
        #expect(store.loadDefaultScanTarget() == .home)
        #expect(store.loadAutoRescanAfterCleanup() == false)
        #expect(store.loadIncludeHiddenByDefault() == false)
        #expect(store.loadIncludePackageContentsByDefault() == false)
        #expect(store.loadExcludeTrashByDefault() == true)
        #expect(store.loadDefaultSmartCareProfile() == .aggressive)
        #expect(store.loadConfirmBeforeDestructiveActions() == false)
        #expect(store.loadConfirmBeforeStartupCleanup() == false)
        #expect(store.loadConfirmBeforeRepairFlows() == true)
        #expect(store.loadAutoRescanAfterRestore() == false)
        #expect(store.loadSelectedTargetBookmark() == bookmarkData)

        store.clearSelectedTargetBookmark()
        #expect(store.loadSelectedTargetBookmark() == nil)
    }

    @Test
    func searchPresetStoreRoundtrip() throws {
        let tempDir = try makeTemporaryDirectory(prefix: "dray-search-store-tests")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let historyStore = OperationalHistoryStore(directoryURL: tempDir)
        let store = SearchPresetStore(historyStore: historyStore)

        let preset = SearchPreset(
            id: UUID(),
            name: "One",
            query: "needle",
            minSizeMB: 1,
            pathContains: "/tmp",
            ownerContains: "me",
            onlyDirectories: false,
            onlyFiles: true,
            useRegex: false,
            depthMin: 0,
            depthMax: 10,
            modifiedWithinDays: nil,
            nodeType: .any,
            searchMode: .live
        )

        store.savePresets([preset])
        let loaded = store.loadPresets()

        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "One")
        #expect(loaded.first?.query == "needle")
    }

    @Test
    func recoveryStoreRoundtrip() throws {
        let tempDir = try makeTemporaryDirectory(prefix: "dray-recovery-store-tests")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let historyStore = OperationalHistoryStore(directoryURL: tempDir)
        let store = RecoveryStore(historyStore: historyStore)
        let session = QuickActionRollbackSession(
            module: .performance,
            actionTitle: "Reduce CPU",
            rollbackKind: .restorePriorities,
            adjustedTargets: ["WindowServer"]
        )

        store.saveQuickActionRollbackSessions([session])
        let loaded = store.loadQuickActionRollbackSessions()

        #expect(loaded.count == 1)
        #expect(loaded.first?.actionTitle == "Reduce CPU")
        #expect(loaded.first?.adjustedTargets == ["WindowServer"])
    }

    private func makeTemporaryDirectory(prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
