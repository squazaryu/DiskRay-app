import Foundation

struct SearchPresetDraft {
    let query: String
    let minSizeMB: Double
    let pathContains: String
    let ownerContains: String
    let onlyDirectories: Bool
    let onlyFiles: Bool
    let useRegex: Bool
    let depthMin: Int
    let depthMax: Int
    let modifiedWithinDays: Int?
    let nodeType: QueryEngine.SearchNodeType
    let searchMode: SearchExecutionMode
}

struct AppliedSearchPreset {
    let query: String
    let minSizeMB: Double
    let pathContains: String
    let ownerContains: String
    let onlyDirectories: Bool
    let onlyFiles: Bool
    let useRegex: Bool
    let depthMin: Int
    let depthMax: Int
    let modifiedWithinDays: Int
    let nodeType: QueryEngine.SearchNodeType
    let searchMode: SearchExecutionMode
}

struct SearchPresetUseCase {
    private let historyStore: OperationalHistoryStore
    private let fileName: String
    private let legacyDefaultsKey: String

    init(
        historyStore: OperationalHistoryStore,
        fileName: String = "search-presets.json",
        legacyDefaultsKey: String = "dray.search.presets"
    ) {
        self.historyStore = historyStore
        self.fileName = fileName
        self.legacyDefaultsKey = legacyDefaultsKey
    }

    func loadPresets() -> [SearchPreset] {
        historyStore.load(
            [SearchPreset].self,
            fileName: fileName,
            legacyDefaultsKey: legacyDefaultsKey
        ) ?? []
    }

    func savePreset(
        named name: String,
        draft: SearchPresetDraft,
        in currentPresets: [SearchPreset]
    ) -> [SearchPreset] {
        let preset = SearchPreset(
            id: UUID(),
            name: name,
            query: draft.query,
            minSizeMB: draft.minSizeMB,
            pathContains: draft.pathContains,
            ownerContains: draft.ownerContains,
            onlyDirectories: draft.onlyDirectories,
            onlyFiles: draft.onlyFiles,
            useRegex: draft.useRegex,
            depthMin: draft.depthMin,
            depthMax: draft.depthMax,
            modifiedWithinDays: draft.modifiedWithinDays,
            nodeType: draft.nodeType,
            searchMode: draft.searchMode
        )
        var updated = currentPresets
        updated.insert(preset, at: 0)
        historyStore.save(updated, fileName: fileName)
        return updated
    }

    func deletePreset(_ preset: SearchPreset, from currentPresets: [SearchPreset]) -> [SearchPreset] {
        let updated = currentPresets.filter { $0.id != preset.id }
        historyStore.save(updated, fileName: fileName)
        return updated
    }

    func apply(_ preset: SearchPreset) -> AppliedSearchPreset {
        AppliedSearchPreset(
            query: preset.query,
            minSizeMB: preset.minSizeMB,
            pathContains: preset.pathContains,
            ownerContains: preset.ownerContains,
            onlyDirectories: preset.onlyDirectories,
            onlyFiles: preset.onlyFiles,
            useRegex: preset.useRegex,
            depthMin: preset.depthMin,
            depthMax: preset.depthMax,
            modifiedWithinDays: preset.modifiedWithinDays ?? 0,
            nodeType: preset.nodeType,
            searchMode: .live
        )
    }
}
