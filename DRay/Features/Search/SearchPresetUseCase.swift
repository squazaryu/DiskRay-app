import Foundation

protocol SearchPresetStoring {
    func loadPresets() -> [SearchPreset]
    func savePresets(_ presets: [SearchPreset])
}

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
    let scopeMode: SearchScopeMode
    let customScopePath: String
    let excludeTrash: Bool
    let includeHidden: Bool
    let includePackageContents: Bool

    init(
        query: String,
        minSizeMB: Double,
        pathContains: String,
        ownerContains: String,
        onlyDirectories: Bool,
        onlyFiles: Bool,
        useRegex: Bool,
        depthMin: Int,
        depthMax: Int,
        modifiedWithinDays: Int?,
        nodeType: QueryEngine.SearchNodeType,
        searchMode: SearchExecutionMode,
        scopeMode: SearchScopeMode = .startupDisk,
        customScopePath: String = "/",
        excludeTrash: Bool = true,
        includeHidden: Bool = true,
        includePackageContents: Bool = true
    ) {
        self.query = query
        self.minSizeMB = minSizeMB
        self.pathContains = pathContains
        self.ownerContains = ownerContains
        self.onlyDirectories = onlyDirectories
        self.onlyFiles = onlyFiles
        self.useRegex = useRegex
        self.depthMin = depthMin
        self.depthMax = depthMax
        self.modifiedWithinDays = modifiedWithinDays
        self.nodeType = nodeType
        self.searchMode = searchMode
        self.scopeMode = scopeMode
        self.customScopePath = customScopePath
        self.excludeTrash = excludeTrash
        self.includeHidden = includeHidden
        self.includePackageContents = includePackageContents
    }
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
    let scopeMode: SearchScopeMode
    let customScopePath: String
    let excludeTrash: Bool
    let includeHidden: Bool
    let includePackageContents: Bool
}

struct SearchPresetUseCase {
    private let store: any SearchPresetStoring

    init(store: any SearchPresetStoring) {
        self.store = store
    }

    func loadPresets() -> [SearchPreset] {
        store.loadPresets()
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
            searchMode: draft.searchMode,
            scopeMode: draft.scopeMode,
            scopePath: draft.customScopePath,
            excludeTrash: draft.excludeTrash,
            includeHidden: draft.includeHidden,
            includePackageContents: draft.includePackageContents
        )
        var updated = currentPresets
        updated.insert(preset, at: 0)
        store.savePresets(updated)
        return updated
    }

    func deletePreset(_ preset: SearchPreset, from currentPresets: [SearchPreset]) -> [SearchPreset] {
        let updated = currentPresets.filter { $0.id != preset.id }
        store.savePresets(updated)
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
            searchMode: .live,
            scopeMode: preset.scopeMode,
            customScopePath: preset.scopePath ?? "/",
            excludeTrash: preset.excludeTrash,
            includeHidden: preset.includeHidden,
            includePackageContents: preset.includePackageContents
        )
    }
}
