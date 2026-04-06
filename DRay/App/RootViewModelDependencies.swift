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
    let privacyService: PrivacyService
    let queryEngine: QueryEngine
    let liveSearchService: LiveSearchService
    let menuBarLoginAgentService: MenuBarLoginAgentService
    let indexStore: SQLiteIndexStore?
    let safeFileOperations: SafeFileOperationService
    let processPriorityService: ProcessPriorityService
    let historyStore: OperationalHistoryStore

    static var live: RootViewModelDependencies {
        RootViewModelDependencies(
            permissions: AppPermissionService(),
            operationLogs: OperationLogStore(),
            scanner: FileScanner(),
            smartScanService: SmartScanService(),
            uninstallerService: AppUninstallerService(),
            duplicateFinderService: DuplicateFinderService(),
            performanceService: PerformanceService(),
            privacyService: PrivacyService(),
            queryEngine: QueryEngine(),
            liveSearchService: LiveSearchService(),
            menuBarLoginAgentService: MenuBarLoginAgentService(),
            indexStore: SQLiteIndexStore(),
            safeFileOperations: SafeFileOperationService(),
            processPriorityService: ProcessPriorityService(),
            historyStore: OperationalHistoryStore()
        )
    }
}
