import Foundation

@MainActor
final class SearchFeatureController: ObservableObject {
    @Published private(set) var state: SearchFeatureState

    private let liveSearchService: LiveSearchService
    private let searchPresetUseCase: SearchPresetUseCase
    private var selectedTargetURL: URL
    private var liveSearchTask: Task<Void, Never>?

    init(
        state: SearchFeatureState = SearchFeatureState(),
        selectedTargetURL: URL,
        liveSearchService: LiveSearchService,
        searchPresetUseCase: SearchPresetUseCase
    ) {
        self.state = state
        self.selectedTargetURL = selectedTargetURL
        self.liveSearchService = liveSearchService
        self.searchPresetUseCase = searchPresetUseCase
    }

    func setSelectedTargetURL(_ url: URL) {
        selectedTargetURL = url
    }

    func update<Value>(_ keyPath: WritableKeyPath<SearchFeatureState, Value>, value: Value) {
        state[keyPath: keyPath] = value
    }

    func loadPresets() {
        state.presets = searchPresetUseCase.loadPresets()
    }

    func runSearch() {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            liveSearchTask?.cancel()
            state.liveResults = []
            state.isLiveRunning = false
            return
        }

        liveSearchTask?.cancel()
        state.isLiveRunning = true

        let request = LiveSearchRequest(
            rootURL: resolvedSearchRootURL(),
            query: query,
            useRegex: state.useRegex,
            pathContains: state.pathContains.lowercased(),
            ownerContains: state.ownerContains.lowercased(),
            minSizeBytes: Int64(state.minSizeMB * 1_048_576),
            depthMin: state.depthMin,
            depthMax: max(state.depthMin, state.depthMax),
            modifiedWithinDays: state.modifiedWithinDays > 0 ? state.modifiedWithinDays : nil,
            nodeType: state.nodeType,
            onlyDirectories: state.onlyDirectories,
            onlyFiles: state.onlyFiles,
            excludeTrash: state.excludeTrash,
            includeHidden: state.includeHidden,
            includePackageContents: state.includePackageContents,
            limit: 50_000
        )

        liveSearchTask = Task { [weak self] in
            guard let self else { return }
            let results = await liveSearchService.search(request)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.state.liveResults = results
                self.state.isLiveRunning = false
            }
        }
    }

    func cancelSearch() {
        liveSearchTask?.cancel()
        state.isLiveRunning = false
    }

    func clearResults() {
        state.liveResults = []
    }

    func savePreset(name: String) {
        let draft = SearchPresetDraft(
            query: state.query,
            minSizeMB: state.minSizeMB,
            pathContains: state.pathContains,
            ownerContains: state.ownerContains,
            onlyDirectories: state.onlyDirectories,
            onlyFiles: state.onlyFiles,
            useRegex: state.useRegex,
            depthMin: state.depthMin,
            depthMax: state.depthMax,
            modifiedWithinDays: state.modifiedWithinDays > 0 ? state.modifiedWithinDays : nil,
            nodeType: state.nodeType,
            searchMode: state.mode,
            scopeMode: state.scopeMode,
            customScopePath: state.customScopePath,
            excludeTrash: state.excludeTrash,
            includeHidden: state.includeHidden,
            includePackageContents: state.includePackageContents
        )
        state.presets = searchPresetUseCase.savePreset(
            named: name,
            draft: draft,
            in: state.presets
        )
    }

    func applyPreset(id: UUID) {
        guard let preset = state.presets.first(where: { $0.id == id }) else { return }
        let appliedPreset = searchPresetUseCase.apply(preset)
        state.query = appliedPreset.query
        state.minSizeMB = appliedPreset.minSizeMB
        state.pathContains = appliedPreset.pathContains
        state.ownerContains = appliedPreset.ownerContains
        state.onlyDirectories = appliedPreset.onlyDirectories
        state.onlyFiles = appliedPreset.onlyFiles
        state.useRegex = appliedPreset.useRegex
        state.depthMin = appliedPreset.depthMin
        state.depthMax = appliedPreset.depthMax
        state.modifiedWithinDays = appliedPreset.modifiedWithinDays
        state.nodeType = appliedPreset.nodeType
        state.mode = appliedPreset.searchMode
        state.scopeMode = appliedPreset.scopeMode
        state.customScopePath = appliedPreset.customScopePath
        state.excludeTrash = appliedPreset.excludeTrash
        state.includeHidden = appliedPreset.includeHidden
        state.includePackageContents = appliedPreset.includePackageContents
        runSearch()
    }

    func deletePreset(id: UUID) {
        guard let preset = state.presets.first(where: { $0.id == id }) else { return }
        state.presets = searchPresetUseCase.deletePreset(preset, from: state.presets)
    }

    private func resolvedSearchRootURL() -> URL {
        switch state.scopeMode {
        case .startupDisk:
            return URL(fileURLWithPath: "/")
        case .selectedTarget:
            return selectedTargetURL
        case .customPath:
            let path = state.customScopePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return URL(fileURLWithPath: "/") }
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            return URL(fileURLWithPath: "/")
        }
    }
}
