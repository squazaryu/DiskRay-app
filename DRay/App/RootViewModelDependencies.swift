import Foundation

@MainActor
struct RootViewModelDependencies {
    let permissions: AppPermissionService
    let operationLogs: OperationLogStore
    let scanner: FileScanner
    let smartScanService: SmartScanService
    let uninstallerService: AppUninstallerService
    let duplicateFinderService: DuplicateFinderService
    let performanceService: PerformanceService
    let batteryDiagnosticsService: BatteryDiagnosticsService
    let networkSpeedTestService: any NetworkSpeedTesting
    let privacyService: PrivacyService
    let liveSearchService: LiveSearchService
    let menuBarLoginAgentService: MenuBarLoginAgentService
    let indexStore: SQLiteIndexStore?
    let safeFileOperations: SafeFileOperationService
    let processPriorityService: ProcessPriorityService
    let historyStore: OperationalHistoryStore
    let searchPresetStore: any SearchPresetStoring
    let recoveryStore: any RecoveryStoring
    let uiSettingsStore: any UISettingsStoring

    static var live: RootViewModelDependencies {
        let historyStore = OperationalHistoryStore()
        return RootViewModelDependencies(
            permissions: AppPermissionService(),
            operationLogs: OperationLogStore(),
            scanner: FileScanner(),
            smartScanService: SmartScanService(),
            uninstallerService: AppUninstallerService(),
            duplicateFinderService: DuplicateFinderService(),
            performanceService: PerformanceService(),
            batteryDiagnosticsService: BatteryDiagnosticsService(),
            networkSpeedTestService: NetworkSpeedTestService(),
            privacyService: PrivacyService(),
            liveSearchService: LiveSearchService(),
            menuBarLoginAgentService: MenuBarLoginAgentService(),
            indexStore: SQLiteIndexStore(),
            safeFileOperations: SafeFileOperationService(),
            processPriorityService: ProcessPriorityService(),
            historyStore: historyStore,
            searchPresetStore: SearchPresetStore(historyStore: historyStore),
            recoveryStore: RecoveryStore(historyStore: historyStore),
            uiSettingsStore: UISettingsStore()
        )
    }
}
