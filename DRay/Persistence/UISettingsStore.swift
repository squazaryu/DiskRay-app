import Foundation

@MainActor
protocol UISettingsStoring {
    func loadAppLanguage() -> AppLanguage?
    func saveAppLanguage(_ language: AppLanguage)

    func loadAppAppearance() -> AppAppearance?
    func saveAppAppearance(_ appearance: AppAppearance)

    func loadAppAccentColor() -> AppAccentColor?
    func saveAppAccentColor(_ accent: AppAccentColor)

    func loadAppInterfaceDensity() -> AppInterfaceDensity?
    func saveAppInterfaceDensity(_ density: AppInterfaceDensity)

    func loadSidebarDisplayMode() -> SidebarDisplayMode?
    func saveSidebarDisplayMode(_ mode: SidebarDisplayMode)

    func loadDefaultScanTarget() -> ScanDefaultTarget?
    func saveDefaultScanTarget(_ target: ScanDefaultTarget)

    func loadAutoRescanAfterCleanup() -> Bool?
    func saveAutoRescanAfterCleanup(_ enabled: Bool)

    func loadIncludeHiddenByDefault() -> Bool?
    func saveIncludeHiddenByDefault(_ enabled: Bool)

    func loadIncludePackageContentsByDefault() -> Bool?
    func saveIncludePackageContentsByDefault(_ enabled: Bool)

    func loadExcludeTrashByDefault() -> Bool?
    func saveExcludeTrashByDefault(_ enabled: Bool)

    func loadDefaultSmartCareProfile() -> SmartCleanProfile?
    func saveDefaultSmartCareProfile(_ profile: SmartCleanProfile)

    func loadConfirmBeforeDestructiveActions() -> Bool?
    func saveConfirmBeforeDestructiveActions(_ enabled: Bool)

    func loadConfirmBeforeStartupCleanup() -> Bool?
    func saveConfirmBeforeStartupCleanup(_ enabled: Bool)

    func loadConfirmBeforeRepairFlows() -> Bool?
    func saveConfirmBeforeRepairFlows(_ enabled: Bool)

    func loadAutoRescanAfterRestore() -> Bool?
    func saveAutoRescanAfterRestore(_ enabled: Bool)

    func loadExperimentalElevatedDeletion() -> Bool?
    func saveExperimentalElevatedDeletion(_ enabled: Bool)

    func loadSelectedTargetBookmark() -> Data?
    func saveSelectedTargetBookmark(_ bookmark: Data)
    func clearSelectedTargetBookmark()
}

@MainActor
struct UISettingsStore: UISettingsStoring {
    private let userDefaults: UserDefaults
    private let appLanguageKey: String
    private let appAppearanceKey: String
    private let appAccentColorKey: String
    private let appInterfaceDensityKey: String
    private let sidebarDisplayModeKey: String
    private let defaultScanTargetKey: String
    private let autoRescanAfterCleanupKey: String
    private let includeHiddenByDefaultKey: String
    private let includePackageContentsByDefaultKey: String
    private let excludeTrashByDefaultKey: String
    private let defaultSmartCareProfileKey: String
    private let confirmBeforeDestructiveActionsKey: String
    private let confirmBeforeStartupCleanupKey: String
    private let confirmBeforeRepairFlowsKey: String
    private let autoRescanAfterRestoreKey: String
    private let experimentalElevatedDeletionKey: String
    private let selectedTargetBookmarkKey: String

    init(
        userDefaults: UserDefaults = .standard,
        appLanguageKey: String = "dray.ui.language",
        appAppearanceKey: String = "dray.ui.appearance",
        appAccentColorKey: String = "dray.ui.accentColor",
        appInterfaceDensityKey: String = "dray.ui.interfaceDensity",
        sidebarDisplayModeKey: String = "dray.ui.sidebarDisplayMode",
        defaultScanTargetKey: String = "dray.scan.default.target",
        autoRescanAfterCleanupKey: String = "dray.scan.autoRescanAfterCleanup",
        includeHiddenByDefaultKey: String = "dray.search.defaults.includeHidden",
        includePackageContentsByDefaultKey: String = "dray.search.defaults.includePackageContents",
        excludeTrashByDefaultKey: String = "dray.search.defaults.excludeTrash",
        defaultSmartCareProfileKey: String = "dray.smartcare.defaultProfile",
        confirmBeforeDestructiveActionsKey: String = "dray.safety.confirm.destructiveActions",
        confirmBeforeStartupCleanupKey: String = "dray.safety.confirm.startupCleanup",
        confirmBeforeRepairFlowsKey: String = "dray.safety.confirm.repairFlows",
        autoRescanAfterRestoreKey: String = "dray.recovery.autoRescanAfterRestore",
        experimentalElevatedDeletionKey: String = "dray.experimental.elevatedDeletion",
        selectedTargetBookmarkKey: String = "dray.scan.target.bookmark"
    ) {
        self.userDefaults = userDefaults
        self.appLanguageKey = appLanguageKey
        self.appAppearanceKey = appAppearanceKey
        self.appAccentColorKey = appAccentColorKey
        self.appInterfaceDensityKey = appInterfaceDensityKey
        self.sidebarDisplayModeKey = sidebarDisplayModeKey
        self.defaultScanTargetKey = defaultScanTargetKey
        self.autoRescanAfterCleanupKey = autoRescanAfterCleanupKey
        self.includeHiddenByDefaultKey = includeHiddenByDefaultKey
        self.includePackageContentsByDefaultKey = includePackageContentsByDefaultKey
        self.excludeTrashByDefaultKey = excludeTrashByDefaultKey
        self.defaultSmartCareProfileKey = defaultSmartCareProfileKey
        self.confirmBeforeDestructiveActionsKey = confirmBeforeDestructiveActionsKey
        self.confirmBeforeStartupCleanupKey = confirmBeforeStartupCleanupKey
        self.confirmBeforeRepairFlowsKey = confirmBeforeRepairFlowsKey
        self.autoRescanAfterRestoreKey = autoRescanAfterRestoreKey
        self.experimentalElevatedDeletionKey = experimentalElevatedDeletionKey
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

    func loadAppAccentColor() -> AppAccentColor? {
        guard let raw = userDefaults.string(forKey: appAccentColorKey) else { return nil }
        return AppAccentColor(rawValue: raw)
    }

    func saveAppAccentColor(_ accent: AppAccentColor) {
        userDefaults.set(accent.rawValue, forKey: appAccentColorKey)
    }

    func loadAppInterfaceDensity() -> AppInterfaceDensity? {
        guard let raw = userDefaults.string(forKey: appInterfaceDensityKey) else { return nil }
        return AppInterfaceDensity(rawValue: raw)
    }

    func saveAppInterfaceDensity(_ density: AppInterfaceDensity) {
        userDefaults.set(density.rawValue, forKey: appInterfaceDensityKey)
    }

    func loadSidebarDisplayMode() -> SidebarDisplayMode? {
        guard let raw = userDefaults.string(forKey: sidebarDisplayModeKey) else { return nil }
        return SidebarDisplayMode(rawValue: raw)
    }

    func saveSidebarDisplayMode(_ mode: SidebarDisplayMode) {
        userDefaults.set(mode.rawValue, forKey: sidebarDisplayModeKey)
    }

    func loadDefaultScanTarget() -> ScanDefaultTarget? {
        guard let raw = userDefaults.string(forKey: defaultScanTargetKey) else { return nil }
        return ScanDefaultTarget(rawValue: raw)
    }

    func saveDefaultScanTarget(_ target: ScanDefaultTarget) {
        userDefaults.set(target.rawValue, forKey: defaultScanTargetKey)
    }

    func loadAutoRescanAfterCleanup() -> Bool? {
        loadBool(forKey: autoRescanAfterCleanupKey)
    }

    func saveAutoRescanAfterCleanup(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: autoRescanAfterCleanupKey)
    }

    func loadIncludeHiddenByDefault() -> Bool? {
        loadBool(forKey: includeHiddenByDefaultKey)
    }

    func saveIncludeHiddenByDefault(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: includeHiddenByDefaultKey)
    }

    func loadIncludePackageContentsByDefault() -> Bool? {
        loadBool(forKey: includePackageContentsByDefaultKey)
    }

    func saveIncludePackageContentsByDefault(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: includePackageContentsByDefaultKey)
    }

    func loadExcludeTrashByDefault() -> Bool? {
        loadBool(forKey: excludeTrashByDefaultKey)
    }

    func saveExcludeTrashByDefault(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: excludeTrashByDefaultKey)
    }

    func loadDefaultSmartCareProfile() -> SmartCleanProfile? {
        guard let raw = userDefaults.string(forKey: defaultSmartCareProfileKey) else { return nil }
        return SmartCleanProfile(rawValue: raw)
    }

    func saveDefaultSmartCareProfile(_ profile: SmartCleanProfile) {
        userDefaults.set(profile.rawValue, forKey: defaultSmartCareProfileKey)
    }

    func loadConfirmBeforeDestructiveActions() -> Bool? {
        loadBool(forKey: confirmBeforeDestructiveActionsKey)
    }

    func saveConfirmBeforeDestructiveActions(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: confirmBeforeDestructiveActionsKey)
    }

    func loadConfirmBeforeStartupCleanup() -> Bool? {
        loadBool(forKey: confirmBeforeStartupCleanupKey)
    }

    func saveConfirmBeforeStartupCleanup(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: confirmBeforeStartupCleanupKey)
    }

    func loadConfirmBeforeRepairFlows() -> Bool? {
        loadBool(forKey: confirmBeforeRepairFlowsKey)
    }

    func saveConfirmBeforeRepairFlows(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: confirmBeforeRepairFlowsKey)
    }

    func loadAutoRescanAfterRestore() -> Bool? {
        loadBool(forKey: autoRescanAfterRestoreKey)
    }

    func saveAutoRescanAfterRestore(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: autoRescanAfterRestoreKey)
    }

    func loadExperimentalElevatedDeletion() -> Bool? {
        loadBool(forKey: experimentalElevatedDeletionKey)
    }

    func saveExperimentalElevatedDeletion(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: experimentalElevatedDeletionKey)
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

    private func loadBool(forKey key: String) -> Bool? {
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.bool(forKey: key)
    }
}
