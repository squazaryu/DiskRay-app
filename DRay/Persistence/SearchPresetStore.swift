import Foundation

struct SearchPresetStore: SearchPresetStoring {
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

    func savePresets(_ presets: [SearchPreset]) {
        historyStore.save(presets, fileName: fileName)
    }
}
