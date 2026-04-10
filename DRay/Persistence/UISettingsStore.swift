import Foundation

@MainActor
protocol UISettingsStoring {
    func loadAppLanguage() -> AppLanguage?
    func saveAppLanguage(_ language: AppLanguage)

    func loadAppAppearance() -> AppAppearance?
    func saveAppAppearance(_ appearance: AppAppearance)

    func loadSelectedTargetBookmark() -> Data?
    func saveSelectedTargetBookmark(_ bookmark: Data)
    func clearSelectedTargetBookmark()
}

@MainActor
struct UISettingsStore: UISettingsStoring {
    private let userDefaults: UserDefaults
    private let appLanguageKey: String
    private let appAppearanceKey: String
    private let selectedTargetBookmarkKey: String

    init(
        userDefaults: UserDefaults = .standard,
        appLanguageKey: String = "dray.ui.language",
        appAppearanceKey: String = "dray.ui.appearance",
        selectedTargetBookmarkKey: String = "dray.scan.target.bookmark"
    ) {
        self.userDefaults = userDefaults
        self.appLanguageKey = appLanguageKey
        self.appAppearanceKey = appAppearanceKey
        self.selectedTargetBookmarkKey = selectedTargetBookmarkKey
    }

    func loadAppLanguage() -> AppLanguage? {
        guard let raw = userDefaults.string(forKey: appLanguageKey) else { return nil }
        return AppLanguage(rawValue: raw)
    }

    func saveAppLanguage(_ language: AppLanguage) {
        userDefaults.set(language.rawValue, forKey: appLanguageKey)
    }

    func loadAppAppearance() -> AppAppearance? {
        guard let raw = userDefaults.string(forKey: appAppearanceKey) else { return nil }
        return AppAppearance(rawValue: raw)
    }

    func saveAppAppearance(_ appearance: AppAppearance) {
        userDefaults.set(appearance.rawValue, forKey: appAppearanceKey)
    }

    func loadSelectedTargetBookmark() -> Data? {
        userDefaults.data(forKey: selectedTargetBookmarkKey)
    }

    func saveSelectedTargetBookmark(_ bookmark: Data) {
        userDefaults.set(bookmark, forKey: selectedTargetBookmarkKey)
    }

    func clearSelectedTargetBookmark() {
        userDefaults.removeObject(forKey: selectedTargetBookmarkKey)
    }
}
