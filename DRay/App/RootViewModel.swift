import Foundation
import AppKit

struct ScanTarget {
    let name: String
    let url: URL
}

struct SearchPreset: Codable, Identifiable {
    let id: UUID
    let name: String
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
    let nodeTypeRaw: String
    let searchModeRaw: String

    var nodeType: QueryEngine.SearchNodeType {
        QueryEngine.SearchNodeType(rawValue: nodeTypeRaw) ?? .any
    }

    var searchMode: SearchExecutionMode {
        SearchExecutionMode(rawValue: searchModeRaw) ?? .live
    }

    init(
        id: UUID,
        name: String,
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
        searchMode: SearchExecutionMode
    ) {
        self.id = id
        self.name = name
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
        self.nodeTypeRaw = nodeType.rawValue
        self.searchModeRaw = searchMode.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case id, name, query, minSizeMB, pathContains, ownerContains, onlyDirectories, onlyFiles
        case useRegex, depthMin, depthMax, modifiedWithinDays, nodeTypeRaw, searchModeRaw
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        query = try c.decode(String.self, forKey: .query)
        minSizeMB = try c.decode(Double.self, forKey: .minSizeMB)
        pathContains = try c.decode(String.self, forKey: .pathContains)
        ownerContains = try c.decodeIfPresent(String.self, forKey: .ownerContains) ?? ""
        onlyDirectories = try c.decode(Bool.self, forKey: .onlyDirectories)
        onlyFiles = try c.decode(Bool.self, forKey: .onlyFiles)
        useRegex = try c.decodeIfPresent(Bool.self, forKey: .useRegex) ?? false
        depthMin = try c.decodeIfPresent(Int.self, forKey: .depthMin) ?? 0
        depthMax = try c.decodeIfPresent(Int.self, forKey: .depthMax) ?? 128
        modifiedWithinDays = try c.decodeIfPresent(Int.self, forKey: .modifiedWithinDays)
        nodeTypeRaw = try c.decodeIfPresent(String.self, forKey: .nodeTypeRaw) ?? QueryEngine.SearchNodeType.any.rawValue
        searchModeRaw = try c.decodeIfPresent(String.self, forKey: .searchModeRaw) ?? SearchExecutionMode.live.rawValue
    }
}

struct TrashOperationResult {
    let moved: Int
    let skippedProtected: [String]
    let failed: [String]
}

struct RecentlyDeletedItem: Codable, Identifiable {
    let id: UUID
    let originalPath: String
    let trashedPath: String
    let deletedAt: Date

    var name: String {
        URL(fileURLWithPath: originalPath).lastPathComponent
    }
}

struct PrivacyCategoryState: Identifiable {
    let id: String
    let category: PrivacyCategory
    var isSelected: Bool
}

struct SmartAnalyzerOption: Identifiable, Hashable {
    let key: String
    let title: String
    let description: String

    var id: String { key }
}

struct UnifiedScanSummary {
    let smartCareCategories: Int
    let smartCareBytes: Int64
    let privacyCategories: Int
    let privacyBytes: Int64
    let startupEntries: Int
    let startupBytes: Int64
    let finishedAt: Date
}

struct DiagnosticReport: Codable {
    let generatedAt: Date
    let selectedTargetPath: String
    let unifiedScanSummary: UnifiedScanSnapshot?
    let smartCareCategoryCount: Int
    let privacyCategoryCount: Int
    let startupEntryCount: Int
    let operationLogs: [OperationLogEntry]
}

struct UnifiedScanSnapshot: Codable {
    let smartCareCategories: Int
    let smartCareBytes: Int64
    let privacyCategories: Int
    let privacyBytes: Int64
    let startupEntries: Int
    let startupBytes: Int64
    let finishedAt: Date
}

enum SearchExecutionMode: String, CaseIterable, Identifiable {
    case live

    var id: String { rawValue }
    var title: String { "Live" }
}

enum SmartCleanProfile: String, CaseIterable, Identifiable {
    case conservative
    case balanced
    case aggressive

    var id: String { rawValue }
    var title: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced: return "Balanced"
        case .aggressive: return "Aggressive"
        }
    }
}

enum AppSection: String, Hashable {
    case smartCare
    case clutter
    case uninstaller
    case repair
    case spaceLens
    case search
    case performance
    case privacy
    case recovery
    case settings
}

enum AppRepairStrategy: String, CaseIterable, Identifiable {
    case safeReset
    case deepReset

    var id: String { rawValue }
    var title: String {
        switch self {
        case .safeReset: return "Safe Reset"
        case .deepReset: return "Deep Reset"
        }
    }

    var subtitle: String {
        switch self {
        case .safeReset:
            return "Targets low-risk caches, logs and preferences."
        case .deepReset:
            return "Includes startup helpers and system-level remnants."
        }
    }
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published var selectedSection: AppSection = .smartCare
    @Published private(set) var root: FileNode?
    @Published private(set) var isLoading = false
    @Published private(set) var selectedTarget = ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
    @Published private(set) var lastScannedTarget: ScanTarget?
    @Published private(set) var progress = ScanProgress(currentPath: "", visitedItems: 0)
    @Published private(set) var isPaused = false
    @Published var search = SearchFeatureState()
    @Published private(set) var recentlyDeleted: [RecentlyDeletedItem] = []
    @Published var hoveredPath: String?
    @Published var smartCare = SmartCareFeatureState()
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var uninstallerRemnants: [AppRemnant] = []
    @Published private(set) var isUninstallerLoading = false
    @Published private(set) var uninstallReport: UninstallValidationReport?
    @Published private(set) var uninstallVerifyReport: UninstallVerifyReport?
    @Published private(set) var isUninstallVerifyRunning = false
    @Published private(set) var uninstallSessions: [UninstallSession] = []
    @Published private(set) var repairArtifacts: [AppRemnant] = []
    @Published private(set) var isRepairLoading = false
    @Published private(set) var repairReport: UninstallValidationReport?
    @Published private(set) var repairSessions: [UninstallSession] = []
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published private(set) var isDuplicateScanRunning = false
    @Published private(set) var duplicateScanProgress = DuplicateScanProgress(
        phase: "Idle",
        currentPath: "",
        visitedFiles: 0,
        candidateGroups: 0
    )
    @Published var duplicateMinSizeMB: Double = 10
    @Published var performance = PerformanceFeatureState()
    @Published private(set) var performanceQuickActionDelta: QuickActionDeltaReport?
    @Published private(set) var privacyCategories: [PrivacyCategoryState] = []
    @Published private(set) var isPrivacyScanRunning = false
    @Published private(set) var privacyCleanReport: PrivacyCleanReport?
    @Published private(set) var privacyQuickActionDelta: QuickActionDeltaReport?
    @Published private(set) var quickActionRollbackSessions: [QuickActionRollbackSession] = []
    @Published private(set) var lastExportedOperationLogURL: URL?
    @Published private(set) var isUnifiedScanRunning = false
    @Published private(set) var unifiedScanSummary: UnifiedScanSummary?
    @Published private(set) var lastExportedDiagnosticURL: URL?
    @Published var permissionBlockingMessage: String?
    @Published private(set) var launchAtLoginEnabled = false
    @Published var appLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: appLanguageKey)
        }
    }
    @Published var appAppearance: AppAppearance = .system {
        didSet {
            UserDefaults.standard.set(appAppearance.rawValue, forKey: appAppearanceKey)
        }
    }

    let permissions: AppPermissionService
    let operationLogs: OperationLogStore

    private let scanner: FileScanner
    private let incrementalTreeMergeUseCase: IncrementalTreeMergeUseCase
    private let permissionGateUseCase: PermissionGateUseCase
    private let searchPresetUseCase: SearchPresetUseCase
    private let uninstallerUseCase: UninstallerUseCase
    private let uninstallSessionUseCase: UninstallSessionUseCase
    private let recoveryHistoryUseCase: RecoveryHistoryUseCase
    private let duplicateFinderService: DuplicateFinderService
    private let performanceUseCase: PerformanceUseCase
    private let smartCareUseCase: SmartCareUseCase
    private let smartExclusionUseCase: SmartExclusionUseCase
    private let privacyService: PrivacyService
    private let queryEngine: QueryEngine
    private let liveSearchService: LiveSearchService
    private let menuBarLoginAgentService: MenuBarLoginAgentService
    private let indexStore: SQLiteIndexStore?
    private let safeFileOperations: SafeFileOperationService
    private let historyStore: OperationalHistoryStore
    private let quickActionRollbackSessionsFileName = "quick-action-rollback-sessions.json"
    private let selectedTargetBookmarkKey = "dray.scan.target.bookmark"
    private let appLanguageKey = "dray.ui.language"
    private let appAppearanceKey = "dray.ui.appearance"
    private var scanTask: Task<Void, Never>?
    private var liveSearchTask: Task<Void, Never>?
    private var duplicateScanTask: Task<Void, Never>?
    let smartAnalyzerOptions: [SmartAnalyzerOption] = [
        .init(key: "user_logs", title: "User Logs", description: "Old files in ~/Library/Logs"),
        .init(key: "user_caches", title: "User Caches", description: "Rebuildable cache files"),
        .init(key: "old_downloads", title: "Old Downloads", description: "Downloads older than 30 days"),
        .init(key: "xcode_derived_data", title: "Xcode DerivedData", description: "Build artifacts"),
        .init(key: "ios_backups", title: "iOS Backups", description: "MobileSync local backups"),
        .init(key: "mail_downloads", title: "Mail Downloads", description: "Saved mail attachments"),
        .init(key: "language_files", title: "Language Files", description: ".lproj localized resources"),
        .init(key: "orphan_preferences", title: "Orphan Preferences", description: "Unused app preference files")
    ]

    init(initialSection: AppSection? = nil, dependencies: RootViewModelDependencies = .live) {
        self.permissions = dependencies.permissions
        self.operationLogs = dependencies.operationLogs
        self.scanner = dependencies.scanner
        self.incrementalTreeMergeUseCase = IncrementalTreeMergeUseCase()
        self.permissionGateUseCase = PermissionGateUseCase(service: dependencies.permissions)
        self.searchPresetUseCase = SearchPresetUseCase(historyStore: dependencies.historyStore)
        self.uninstallerUseCase = UninstallerUseCase(service: dependencies.uninstallerService)
        self.duplicateFinderService = dependencies.duplicateFinderService
        self.smartCareUseCase = SmartCareUseCase(service: dependencies.smartScanService)
        self.smartExclusionUseCase = SmartExclusionUseCase()
        self.performanceUseCase = PerformanceUseCase(
            performanceService: dependencies.performanceService,
            processPriorityService: dependencies.processPriorityService
        )
        self.privacyService = dependencies.privacyService
        self.queryEngine = dependencies.queryEngine
        self.liveSearchService = dependencies.liveSearchService
        self.menuBarLoginAgentService = dependencies.menuBarLoginAgentService
        self.indexStore = dependencies.indexStore
        self.safeFileOperations = dependencies.safeFileOperations
        self.historyStore = dependencies.historyStore
        self.uninstallSessionUseCase = UninstallSessionUseCase(
            historyStore: dependencies.historyStore,
            safeFileOperations: dependencies.safeFileOperations
        )
        self.recoveryHistoryUseCase = RecoveryHistoryUseCase(
            historyStore: dependencies.historyStore,
            safeFileOperations: dependencies.safeFileOperations
        )

        if let storedLanguage = UserDefaults.standard.string(forKey: appLanguageKey),
           let language = AppLanguage(rawValue: storedLanguage) {
            appLanguage = language
        }
        if let storedAppearance = UserDefaults.standard.string(forKey: appAppearanceKey),
           let appearance = AppAppearance(rawValue: storedAppearance) {
            appAppearance = appearance
        }
        restoreLastTargetIfPossible()
        loadSearchPresets()
        loadRecentlyDeleted()
        loadQuickActionRollbackSessions()
        loadSmartExclusions()
        loadUninstallSessions()
        loadRepairSessions()
        refreshLaunchAtLoginStatus()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        if let initialSection {
            selectedSection = initialSection
        }
    }

    private var searchQuery: String {
        get { search.query }
        set { search.query = newValue }
    }

    private var minSizeMB: Double {
        get { search.minSizeMB }
        set { search.minSizeMB = newValue }
    }

    private var pathContains: String {
        get { search.pathContains }
        set { search.pathContains = newValue }
    }

    private var ownerContains: String {
        get { search.ownerContains }
        set { search.ownerContains = newValue }
    }

    private var onlyDirectories: Bool {
        get { search.onlyDirectories }
        set { search.onlyDirectories = newValue }
    }

    private var onlyFiles: Bool {
        get { search.onlyFiles }
        set { search.onlyFiles = newValue }
    }

    private var searchUseRegex: Bool {
        get { search.useRegex }
        set { search.useRegex = newValue }
    }

    private var searchDepthMin: Int {
        get { search.depthMin }
        set { search.depthMin = newValue }
    }

    private var searchDepthMax: Int {
        get { search.depthMax }
        set { search.depthMax = newValue }
    }

    private var searchModifiedWithinDays: Int {
        get { search.modifiedWithinDays }
        set { search.modifiedWithinDays = newValue }
    }

    private var searchNodeType: QueryEngine.SearchNodeType {
        get { search.nodeType }
        set { search.nodeType = newValue }
    }

    private var searchMode: SearchExecutionMode {
        get { search.mode }
        set { search.mode = newValue }
    }

    private var isLiveSearchRunning: Bool {
        get { search.isLiveRunning }
        set { search.isLiveRunning = newValue }
    }

    private var liveSearchResults: [FileNode] {
        get { search.liveResults }
        set { search.liveResults = newValue }
    }

    private var searchPresets: [SearchPreset] {
        get { search.presets }
        set { search.presets = newValue }
    }

    private var smartScanCategories: [SmartCategoryState] {
        get { smartCare.categories }
        set { smartCare.categories = newValue }
    }

    private var isSmartScanRunning: Bool {
        get { smartCare.isScanRunning }
        set { smartCare.isScanRunning = newValue }
    }

    private var smartExclusions: [String] {
        get { smartCare.exclusions }
        set { smartCare.exclusions = newValue }
    }

    private var smartExcludedAnalyzerKeys: [String] {
        get { smartCare.excludedAnalyzerKeys }
        set { smartCare.excludedAnalyzerKeys = newValue }
    }

    private var smartAnalyzerTelemetry: [CleanupAnalyzerTelemetry] {
        get { smartCare.analyzerTelemetry }
        set { smartCare.analyzerTelemetry = newValue }
    }

    private var smartMinCleanSizeMB: Double {
        get { smartCare.minCleanSizeMB }
        set { smartCare.minCleanSizeMB = newValue }
    }

    private var smartProfile: SmartCleanProfile {
        get { smartCare.profile }
        set { smartCare.profile = newValue }
    }

    private(set) var performanceReport: PerformanceReport? {
        get { performance.report }
        set { performance.report = newValue }
    }

    private(set) var isPerformanceScanRunning: Bool {
        get { performance.isScanRunning }
        set { performance.isScanRunning = newValue }
    }

    private(set) var startupCleanupReport: StartupCleanupReport? {
        get { performance.startupCleanupReport }
        set { performance.startupCleanupReport = newValue }
    }

    private(set) var activeLoadReliefAdjustments: Int {
        get { performance.activeLoadReliefAdjustments }
        set { performance.activeLoadReliefAdjustments = newValue }
    }

    var searchResults: [FileNode] {
        search.results
    }

    var appVersionDisplay: String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (info?["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch (version, build) {
        case let (v?, b?) where !v.isEmpty && !b.isEmpty && v != b:
            return "\(v) (\(b))"
        case let (v?, _) where !v.isEmpty:
            return v
        case let (_, b?) where !b.isEmpty:
            return b
        default:
            return "dev"
        }
    }

    func localized(_ key: AppL10nKey) -> String {
        AppL10n.text(key, language: appLanguage)
    }

    func localizedSectionTitle(for section: AppSection) -> String {
        AppL10n.sectionTitle(section, language: appLanguage)
    }

    func triggerLiveSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            liveSearchTask?.cancel()
            liveSearchResults = []
            isLiveSearchRunning = false
            return
        }

        liveSearchTask?.cancel()
        isLiveSearchRunning = true
        let rootURL = selectedTarget.url
        let modeType = searchNodeType
        let useRegex = searchUseRegex
        let pathContains = self.pathContains.lowercased()
        let ownerContains = self.ownerContains.lowercased()
        let minSize = Int64(minSizeMB * 1_048_576)
        let depthMin = searchDepthMin
        let depthMax = max(searchDepthMin, searchDepthMax)
        let modifiedWithinDays = searchModifiedWithinDays > 0 ? searchModifiedWithinDays : nil
        let onlyDirs = onlyDirectories
        let onlyFiles = onlyFiles

        liveSearchTask = Task { [weak self] in
            guard let self else { return }
            let request = LiveSearchRequest(
                rootURL: rootURL,
                query: query,
                useRegex: useRegex,
                pathContains: pathContains,
                ownerContains: ownerContains,
                minSizeBytes: minSize,
                depthMin: depthMin,
                depthMax: depthMax,
                modifiedWithinDays: modifiedWithinDays,
                nodeType: modeType,
                onlyDirectories: onlyDirs,
                onlyFiles: onlyFiles,
                limit: 300
            )
            let results = await self.liveSearchService.search(request)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.liveSearchResults = results
                self.isLiveSearchRunning = false
            }
        }
    }

    func cancelLiveSearch() {
        liveSearchTask?.cancel()
        isLiveSearchRunning = false
    }

    func clearLiveSearchResults() {
        liveSearchResults = []
    }

    var selectedTargetPath: String {
        selectedTarget.url.path
    }

    func openSection(_ section: AppSection) {
        selectedSection = section
    }

    func refreshPermissions() {
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        if permissions.hasFolderPermission && permissions.hasFullDiskAccess {
            permissions.markOnboardingCompleted()
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = menuBarLoginAgentService.isEnabled()
    }

    func toggleLaunchAtLogin() {
        let target = !launchAtLoginEnabled
        let success = menuBarLoginAgentService.setEnabled(target)
        refreshLaunchAtLoginStatus()
        if success {
            operationLogs.add(
                category: "telemetry",
                message: "Launch-at-login \(launchAtLoginEnabled ? "enabled" : "disabled")"
            )
        } else {
            permissionBlockingMessage = "Failed to update launch-at-login setting."
            operationLogs.add(category: "telemetry", message: "Failed to change launch-at-login setting")
        }
    }

    func clearPermissionBlockingMessage() {
        permissionBlockingMessage = nil
    }

    func reduceCPULoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        let beforeAdjustments = activeLoadReliefAdjustments
        let result = performanceUseCase.reduceCPULoad(consumers: consumers, limit: limit)
        activeLoadReliefAdjustments = performanceUseCase.activeAdjustmentsCount
        recordQuickActionRollbackSession(
            actionTitle: "Reduce CPU",
            rollbackKind: .restorePriorities,
            adjustedTargets: result.adjusted,
            beforeItems: beforeAdjustments,
            afterItems: activeLoadReliefAdjustments
        )
        operationLogs.add(
            category: "relief",
            message: "Load relief (cpu): adjusted \(result.adjusted.count), skipped \(result.skipped.count), failed \(result.failed.count)"
        )
        return result
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        let beforeAdjustments = activeLoadReliefAdjustments
        let result = performanceUseCase.reduceMemoryLoad(consumers: consumers, limit: limit)
        activeLoadReliefAdjustments = performanceUseCase.activeAdjustmentsCount
        recordQuickActionRollbackSession(
            actionTitle: "Reduce Memory",
            rollbackKind: .restorePriorities,
            adjustedTargets: result.adjusted,
            beforeItems: beforeAdjustments,
            afterItems: activeLoadReliefAdjustments
        )
        operationLogs.add(
            category: "relief",
            message: "Load relief (memory): adjusted \(result.adjusted.count), skipped \(result.skipped.count), failed \(result.failed.count)"
        )
        return result
    }

    func restoreAdjustedProcessPriorities(limit: Int = 5) -> LoadReliefResult {
        let result = performanceUseCase.restoreAdjustedPriorities(limit: limit)
        activeLoadReliefAdjustments = performanceUseCase.activeAdjustmentsCount
        markLatestQuickRollbackSessionResolved(
            summary: "Restored \(result.adjusted.count), failed \(result.failed.count), skipped \(result.skipped.count)"
        )
        operationLogs.add(
            category: "relief",
            message: "Load relief restore: restored \(result.adjusted.count), skipped \(result.skipped.count), failed \(result.failed.count)"
        )
        return result
    }

    func selectMacDisk() {
        selectedTarget = ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
        clearSavedTargetBookmark()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        triggerLiveSearch()
    }

    func selectHome() {
        let url = FileManager.default.homeDirectoryForCurrentUser
        selectedTarget = ScanTarget(name: "Home", url: url)
        clearSavedTargetBookmark()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        triggerLiveSearch()
    }

    func selectFolder(_ url: URL) {
        let scopedURL = persistAndResolveBookmark(for: url) ?? url
        selectedTarget = ScanTarget(name: scopedURL.lastPathComponent, url: scopedURL)
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        if permissions.hasFolderPermission && permissions.hasFullDiskAccess {
            permissions.markOnboardingCompleted()
        }
        triggerLiveSearch()
    }

    func scanSelected() {
        guard ensureCanScanSelectedTarget() else { return }
        operationLogs.add(category: "scan", message: "User triggered scan for \(selectedTarget.url.path)")
        // Keep root scans full to avoid shallow-size artifacts on top-level system directories.
        if selectedTarget.url.path == "/" {
            scan(at: selectedTarget.url, maxDepth: 7)
            return
        }
        if let cached = indexStore?.loadSnapshot(rootPath: selectedTarget.url.path) {
            root = cached
            scanIncremental(at: selectedTarget.url, base: cached)
            return
        }
        scan(at: selectedTarget.url, maxDepth: 7)
    }

    func runSmartScan() {
        guard !isSmartScanRunning else { return }
        guard ensureCanRunProtectedModule(actionName: "Smart Scan") else { return }
        isSmartScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await smartCareUseCase.runScan(
                excludedPrefixes: smartExclusions,
                excludedAnalyzerKeys: smartExcludedAnalyzerKeys
            )
            await MainActor.run {
                self.applySmartScanResult(result)
                self.isSmartScanRunning = false
                self.operationLogs.add(category: "smartcare", message: "Smart scan done: categories \(result.categories.count), bytes \(result.totalBytes)")
            }
        }
    }

    func toggleSmartCategorySelection(_ id: String) {
        guard let index = smartScanCategories.firstIndex(where: { $0.id == id }) else { return }
        smartScanCategories[index].isSelected.toggle()
    }

    func cleanSelectedSmartCategories() {
        let items = smartScanCategories
            .filter(\.isSelected)
            .flatMap { $0.result.items }

        guard !items.isEmpty else { return }
        guard ensureCanModify(urls: items.map(\.url), actionName: "Smart Clean") else { return }

        Task { [weak self] in
            guard let self else { return }
            // Manual category selection should clean exactly what user selected,
            // without hidden size threshold filtering.
            let cleanupResult = await smartCareUseCase.clean(items: items, minSizeBytes: 0)
            await MainActor.run {
                AppLogger.actions.info("Smart clean moved: \(cleanupResult.moved), failed: \(cleanupResult.failed)")
                self.operationLogs.add(category: "smartcare", message: "Smart clean moved \(cleanupResult.moved), failed \(cleanupResult.failed)")
                self.runSmartScan()
            }
        }
    }

    func cleanRecommendedSmartCategories() {
        selectRecommendedSmartCategories()
        let items = smartScanCategories
            .filter(\.isSelected)
            .flatMap { $0.result.items }

        guard !items.isEmpty else { return }
        guard ensureCanModify(urls: items.map(\.url), actionName: "Smart Clean") else { return }

        Task { [weak self] in
            guard let self else { return }
            // Keep min-size threshold for auto-recommended cleanup flow.
            let cleanupResult = await smartCareUseCase.clean(
                items: items,
                minSizeBytes: Int64(smartMinCleanSizeMB * 1_048_576)
            )
            await MainActor.run {
                AppLogger.actions.info("Smart recommended clean moved: \(cleanupResult.moved), failed: \(cleanupResult.failed)")
                self.operationLogs.add(category: "smartcare", message: "Smart recommended clean moved \(cleanupResult.moved), failed \(cleanupResult.failed)")
                self.runSmartScan()
            }
        }
    }

    func cleanSmartItems(_ items: [CleanupItem]) {
        guard !items.isEmpty else { return }
        guard ensureCanModify(urls: items.map(\.url), actionName: "Smart Clean") else { return }
        Task { [weak self] in
            guard let self else { return }
            // Manual item selection should clean exact picks, regardless of min size.
            let cleanupResult = await smartCareUseCase.clean(items: items, minSizeBytes: 0)
            await MainActor.run {
                AppLogger.actions.info("Smart item clean moved: \(cleanupResult.moved), failed: \(cleanupResult.failed)")
                self.operationLogs.add(category: "smartcare", message: "Smart item clean moved \(cleanupResult.moved), failed \(cleanupResult.failed)")
                self.runSmartScan()
            }
        }
    }

    func selectRecommendedSmartCategories() {
        smartScanCategories = smartCareUseCase.applyRecommendations(
            to: smartScanCategories,
            profile: smartProfile
        )
    }

    func applySmartProfile(_ profile: SmartCleanProfile) {
        smartProfile = profile
        switch profile {
        case .conservative: smartMinCleanSizeMB = 8
        case .balanced: smartMinCleanSizeMB = 1
        case .aggressive: smartMinCleanSizeMB = 0.1
        }
        selectRecommendedSmartCategories()
    }

    func addSmartExclusion(_ path: String) {
        smartExclusions = smartExclusionUseCase.addPath(path, to: smartExclusions)
    }

    func toggleSmartExclusion(_ path: String) {
        smartExclusions = smartExclusionUseCase.togglePath(path, currentPaths: smartExclusions)
    }


    func loadInstalledApps() {
        isUninstallerLoading = true
        Task { [weak self] in
            guard let self else { return }
            let apps = await uninstallerUseCase.installedApps()
            await MainActor.run {
                self.installedApps = apps
                self.isUninstallerLoading = false
            }
        }
    }

    func loadRemnants(for app: InstalledApp) {
        isUninstallerLoading = true
        Task { [weak self] in
            guard let self else { return }
            let remnants = await uninstallerUseCase.findRemnants(for: app)
            await MainActor.run {
                self.uninstallerRemnants = remnants
                self.uninstallReport = nil
                self.uninstallVerifyReport = nil
                self.isUninstallerLoading = false
            }
        }
    }

    func uninstall(app: InstalledApp, selectedItems: [UninstallPreviewItem]? = nil) {
        guard ensureCanRunProtectedModule(actionName: "Uninstall") else { return }
        let preview = uninstallPreview(for: app)
        let items = selectedItems ?? preview
        guard ensureCanModify(urls: items.map(\.url), actionName: "Uninstall", requiresFullDisk: true) else { return }
        isUninstallVerifyRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerUseCase.uninstallAndVerify(
                app: app,
                previewItems: items,
                isProtectedPath: { path in
                    self.safeFileOperations.isProtectedPath(path)
                },
                isAppRunning: !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
            )
            await MainActor.run {
                let validation = result.validation
                AppLogger.actions.info("Uninstall removed: \(validation.removedCount), skipped: \(validation.skippedCount), failed: \(validation.failedCount)")
                self.operationLogs.add(category: "uninstaller", message: "Uninstall \(app.name): removed \(validation.removedCount), skipped \(validation.skippedCount), failed \(validation.failedCount)")
                self.uninstallReport = validation
                self.uninstallVerifyReport = result.verifyReport
                self.isUninstallVerifyRunning = false
                self.uninstallSessions = self.uninstallSessionUseCase.appendSession(
                    from: validation,
                    existingSessions: self.uninstallSessions,
                    kind: .uninstall
                )
                self.uninstallerRemnants = result.remainingRemnants
                self.loadInstalledApps()
            }
        }
    }

    func runUninstallVerifyPass(for app: InstalledApp) {
        let preview = uninstallPreview(for: app)
        let validation = uninstallReport
        isUninstallVerifyRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerUseCase.runVerifyPass(
                app: app,
                previewItems: preview,
                validation: validation,
                isProtectedPath: { path in
                    self.safeFileOperations.isProtectedPath(path)
                },
                isAppRunning: !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
            )
            await MainActor.run {
                self.uninstallerRemnants = result.remainingRemnants
                self.uninstallVerifyReport = result.verifyReport
                self.isUninstallVerifyRunning = false
            }
        }
    }

    func loadRepairArtifacts(for app: InstalledApp) {
        isRepairLoading = true
        Task { [weak self] in
            guard let self else { return }
            let artifacts = await uninstallerUseCase.findRemnants(for: app)
            await MainActor.run {
                self.repairArtifacts = artifacts
                self.repairReport = nil
                self.isRepairLoading = false
            }
        }
    }

    func runAppRepair(app: InstalledApp, artifacts: [AppRemnant], relaunchAfterRepair: Bool) {
        guard !artifacts.isEmpty else { return }
        guard ensureCanRunProtectedModule(actionName: "App Repair") else { return }
        guard ensureCanModify(urls: artifacts.map(\.url), actionName: "App Repair", requiresFullDisk: true) else { return }
        isRepairLoading = true
        let previewItems = artifacts.map {
            UninstallPreviewItem(
                url: $0.url,
                type: .remnant,
                sizeInBytes: $0.sizeInBytes,
                risk: .low,
                reason: "App repair artifact cleanup"
            )
        }
        Task { [weak self] in
            guard let self else { return }
            let report = await uninstallerUseCase.uninstall(app: app, previewItems: previewItems)
            await MainActor.run {
                self.repairReport = report
                self.isRepairLoading = false
                self.repairSessions = self.uninstallSessionUseCase.appendSession(
                    from: report,
                    existingSessions: self.repairSessions,
                    kind: .repair
                )
                self.operationLogs.add(
                    category: "repair",
                    message: "Repair \(app.name): removed \(report.removedCount), skipped \(report.skippedCount), failed \(report.failedCount)"
                )
                self.loadRepairArtifacts(for: app)
                if relaunchAfterRepair {
                    self.relaunchApp(app)
                }
            }
        }
    }

    func recommendedRepairArtifacts(for strategy: AppRepairStrategy) -> [AppRemnant] {
        switch strategy {
        case .safeReset:
            return repairArtifacts.filter { repairRisk(for: $0) == .low }
        case .deepReset:
            return repairArtifacts
        }
    }

    func repairRisk(for artifact: AppRemnant) -> UninstallRiskLevel {
        uninstallerUseCase.repairRisk(for: artifact)
    }

    func restoreFromUninstallSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> Int {
        let result = uninstallSessionUseCase.restore(
            from: session,
            item: item,
            sessions: uninstallSessions,
            kind: .uninstall
        )
        let restored = result.restoredCount

        if restored > 0 {
            operationLogs.add(category: "uninstaller", message: "Rollback restored \(restored) item(s) for \(session.appName)")
            uninstallSessions = result.sessions
        }
        if !result.failures.isEmpty {
            for failure in result.failures {
                AppLogger.actions.error("Failed uninstall rollback restore: \(failure.reason, privacy: .public)")
            }
        }
        return restored
    }

    func restoreFromRepairSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> Int {
        let result = uninstallSessionUseCase.restore(
            from: session,
            item: item,
            sessions: repairSessions,
            kind: .repair
        )
        let restored = result.restoredCount

        if restored > 0 {
            operationLogs.add(category: "repair", message: "Repair rollback restored \(restored) item(s) for \(session.appName)")
            repairSessions = result.sessions
        }
        if !result.failures.isEmpty {
            for failure in result.failures {
                AppLogger.actions.error("Failed repair rollback restore: \(failure.reason, privacy: .public)")
            }
        }
        return restored
    }

    func uninstallPreview(for app: InstalledApp) -> [UninstallPreviewItem] {
        uninstallerUseCase.uninstallPreview(app: app, remnants: uninstallerRemnants)
    }

    func removeSmartExclusion(_ path: String) {
        smartExclusions = smartExclusionUseCase.removePath(path, from: smartExclusions)
    }

    func toggleSmartAnalyzerExclusion(_ analyzerKey: String) {
        let previouslyExcluded = smartExcludedAnalyzerKeys.contains(analyzerKey)
        smartExcludedAnalyzerKeys = smartExclusionUseCase.toggleAnalyzer(
            analyzerKey,
            currentAnalyzerKeys: smartExcludedAnalyzerKeys
        )
        if analyzerKey.isEmpty {
            return
        }
        if previouslyExcluded {
            operationLogs.add(category: "smartcare", message: "Analyzer enabled: \(analyzerKey)")
        } else {
            operationLogs.add(category: "smartcare", message: "Analyzer excluded: \(analyzerKey)")
        }
    }

    func applySmartScanResult(_ result: SmartScanResult) {
        smartScanCategories = result.categories.map {
            SmartCategoryState(id: $0.key, result: $0, isSelected: $0.isSafeByDefault)
        }
        smartAnalyzerTelemetry = result.analyzerTelemetry
        selectRecommendedSmartCategories()
    }


    func scanDuplicatesInSelectedTarget() {
        scanDuplicates(roots: [selectedTarget.url], targetDescription: selectedTarget.url.path)
    }

    func scanDuplicatesInHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        scanDuplicates(roots: [home], targetDescription: home.path)
    }

    func cancelDuplicateScan() {
        duplicateScanTask?.cancel()
        isDuplicateScanRunning = false
        duplicateScanProgress = DuplicateScanProgress(
            phase: "Canceled",
            currentPath: duplicateScanProgress.currentPath,
            visitedFiles: duplicateScanProgress.visitedFiles,
            candidateGroups: duplicateScanProgress.candidateGroups
        )
        operationLogs.add(category: "clutter", message: "Duplicate scan canceled")
    }

    func clearDuplicateResults() {
        duplicateGroups = []
    }

    func moveDuplicatePathsToTrash(_ paths: [String]) -> TrashOperationResult {
        var nodes: [FileNode] = []
        var missingPaths: [String] = []
        for path in paths {
            if let node = nodeForPath(path) {
                nodes.append(node)
            } else {
                missingPaths.append(path)
            }
        }

        let baseResult = moveToTrash(nodes: nodes)
        let result: TrashOperationResult
        if missingPaths.isEmpty {
            result = baseResult
        } else {
            result = TrashOperationResult(
                moved: baseResult.moved,
                skippedProtected: baseResult.skippedProtected,
                failed: baseResult.failed + missingPaths
            )
        }
        let attempted = Set(paths)
        let skipped = Set(result.skippedProtected)
        let failed = Set(result.failed)
        let movedPaths = attempted.subtracting(skipped).subtracting(failed)
        if !movedPaths.isEmpty {
            duplicateGroups = duplicateGroups.compactMap { group in
                let remaining = group.files.filter { !movedPaths.contains($0.url.path) }
                guard remaining.count > 1 else { return nil }
                return DuplicateGroup(
                    signature: group.signature,
                    files: remaining,
                    sizeInBytes: group.sizeInBytes
                )
            }
            operationLogs.add(
                category: "clutter",
                message: "Duplicate cleanup moved \(movedPaths.count) file(s), failed \(result.failed.count), skipped \(result.skippedProtected.count)"
            )
        }
        return result
    }

    func runPerformanceScan() {
        guard !isPerformanceScanRunning else { return }
        guard ensureCanRunProtectedModule(actionName: "Performance Diagnostics") else { return }
        isPerformanceScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let report = await performanceUseCase.runDiagnostics()
            await MainActor.run {
                self.performanceReport = report
                self.startupCleanupReport = nil
                self.isPerformanceScanRunning = false
                self.operationLogs.add(category: "performance", message: "Diagnostics done: startup entries \(report.startupEntries.count)")
            }
        }
    }

    private func scanDuplicates(roots: [URL], targetDescription: String) {
        duplicateScanTask?.cancel()
        isDuplicateScanRunning = true
        duplicateGroups = []
        let minSizeBytes = Int64(max(1, duplicateMinSizeMB) * 1_048_576)
        duplicateScanProgress = DuplicateScanProgress(
            phase: "Starting",
            currentPath: targetDescription,
            visitedFiles: 0,
            candidateGroups: 0
        )
        operationLogs.add(
            category: "clutter",
            message: "Duplicate scan started for \(targetDescription), min size \(Int(duplicateMinSizeMB)) MB"
        )

        duplicateScanTask = Task { [weak self] in
            guard let self else { return }
            let groups = await duplicateFinderService.scan(
                roots: roots,
                minFileSizeBytes: minSizeBytes
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.duplicateScanProgress = progress
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.duplicateGroups = groups
                self.isDuplicateScanRunning = false
                self.duplicateScanProgress = DuplicateScanProgress(
                    phase: "Completed",
                    currentPath: targetDescription,
                    visitedFiles: self.duplicateScanProgress.visitedFiles,
                    candidateGroups: groups.count
                )
                self.operationLogs.add(
                    category: "clutter",
                    message: "Duplicate scan completed for \(targetDescription): groups \(groups.count)"
                )
            }
        }
    }

    private func nodeForPath(_ path: String) -> FileNode? {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return FileNode(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDirectory.boolValue,
            sizeInBytes: size,
            children: []
        )
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) {
        guard !entries.isEmpty else { return }
        guard ensureCanModify(urls: entries.map(\.url), actionName: "Startup Cleanup", requiresFullDisk: true) else { return }
        let before = startupTotals(from: performanceReport)
        isPerformanceScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let report = await performanceUseCase.cleanupStartupEntries(entries)
            let refreshedReport = await performanceUseCase.runDiagnostics()
            let after = startupTotals(from: refreshedReport)
            await MainActor.run {
                self.startupCleanupReport = report
                self.performanceReport = refreshedReport
                self.isPerformanceScanRunning = false
                let delta = QuickActionDeltaReport(
                    module: .performance,
                    actionTitle: "Startup Cleanup",
                    beforeItems: before.items,
                    beforeBytes: before.bytes,
                    afterItems: after.items,
                    afterBytes: after.bytes,
                    moved: report.moved,
                    failed: report.failed,
                    skippedProtected: report.skippedProtected
                )
                self.performanceQuickActionDelta = delta
                self.operationLogs.add(category: "performance", message: "Startup cleanup moved \(report.moved), failed \(report.failed), skipped \(report.skippedProtected)")
                self.operationLogs.add(
                    category: "performance",
                    message: "Startup cleanup delta: items \(before.items)->\(after.items), bytes \(before.bytes)->\(after.bytes)"
                )
            }
        }
    }

    func runPrivacyScan() {
        guard !isPrivacyScanRunning else { return }
        guard ensureCanRunProtectedModule(actionName: "Privacy Scan") else { return }
        isPrivacyScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let report = await privacyService.runScan()
            await MainActor.run {
                self.privacyCategories = report.categories.map { category in
                    PrivacyCategoryState(id: category.id, category: category, isSelected: false)
                }
                self.privacyCleanReport = nil
                self.isPrivacyScanRunning = false
                self.operationLogs.add(category: "privacy", message: "Privacy scan done: categories \(report.categories.count), bytes \(report.totalBytes)")
            }
        }
    }

    func runUnifiedScan() {
        guard !isUnifiedScanRunning else { return }
        guard ensureCanRunProtectedModule(actionName: "Unified Scan") else { return }
        isUnifiedScanRunning = true
        operationLogs.add(category: "scan", message: "Unified scan started")

        Task { [weak self] in
            guard let self else { return }
            async let smartResult = smartCareUseCase.runScan(
                excludedPrefixes: smartExclusions,
                excludedAnalyzerKeys: smartExcludedAnalyzerKeys
            )
            async let privacyResult = privacyService.runScan()
            async let performanceResult = performanceUseCase.runDiagnostics()

            let (smart, privacy, performance) = await (smartResult, privacyResult, performanceResult)

            await MainActor.run {
                self.applySmartScanResult(smart)

                self.privacyCategories = privacy.categories.map {
                    PrivacyCategoryState(id: $0.id, category: $0, isSelected: false)
                }

                self.performanceReport = performance
                self.startupCleanupReport = nil

                self.unifiedScanSummary = UnifiedScanSummary(
                    smartCareCategories: smart.categories.count,
                    smartCareBytes: smart.totalBytes,
                    privacyCategories: privacy.categories.count,
                    privacyBytes: privacy.totalBytes,
                    startupEntries: performance.startupEntries.count,
                    startupBytes: performance.startupTotalBytes,
                    finishedAt: Date()
                )

                self.isUnifiedScanRunning = false
                self.operationLogs.add(
                    category: "scan",
                    message: "Unified scan done: smart \(smart.categories.count), privacy \(privacy.categories.count), startup \(performance.startupEntries.count)"
                )
            }
        }
    }

    func togglePrivacyCategory(_ id: String) {
        guard let idx = privacyCategories.firstIndex(where: { $0.id == id }) else { return }
        privacyCategories[idx].isSelected.toggle()
    }

    func clearPrivacySelection() {
        for index in privacyCategories.indices {
            privacyCategories[index].isSelected = false
        }
    }

    func selectRecommendedPrivacyCategories(includeMediumRisk: Bool) {
        for index in privacyCategories.indices {
            let risk = privacyCategories[index].category.risk
            switch risk {
            case .low:
                privacyCategories[index].isSelected = true
            case .medium:
                privacyCategories[index].isSelected = includeMediumRisk
            case .high:
                privacyCategories[index].isSelected = false
            }
        }
    }

    func cleanRecommendedPrivacyCategories(includeMediumRisk: Bool) {
        selectRecommendedPrivacyCategories(includeMediumRisk: includeMediumRisk)
        let actionTitle = includeMediumRisk ? "Quick Clean Recommended" : "Quick Clean Safe"
        cleanSelectedPrivacyCategories(actionTitle: actionTitle)
    }

    func cleanSelectedPrivacyCategories() {
        cleanSelectedPrivacyCategories(actionTitle: "Clean Selected")
    }

    private func cleanSelectedPrivacyCategories(actionTitle: String) {
        let artifacts = privacyCategories
            .filter(\.isSelected)
            .flatMap(\.category.artifacts)
        guard !artifacts.isEmpty else { return }
        guard ensureCanModify(urls: artifacts.map(\.url), actionName: "Privacy Cleanup", requiresFullDisk: true) else { return }
        let before = privacyTotals(from: privacyCategories)

        Task { [weak self] in
            guard let self else { return }
            let report = await privacyService.clean(artifacts: artifacts)
            let refreshed = await privacyService.runScan()
            let refreshedCategories = refreshed.categories.map { category in
                PrivacyCategoryState(id: category.id, category: category, isSelected: false)
            }
            let after = privacyTotals(from: refreshedCategories)
            await MainActor.run {
                self.privacyCleanReport = report
                self.privacyCategories = refreshedCategories
                let delta = QuickActionDeltaReport(
                    module: .privacy,
                    actionTitle: actionTitle,
                    beforeItems: before.items,
                    beforeBytes: before.bytes,
                    afterItems: after.items,
                    afterBytes: after.bytes,
                    moved: report.moved,
                    failed: report.failed,
                    skippedProtected: report.skippedProtected
                )
                self.privacyQuickActionDelta = delta
                self.operationLogs.add(category: "privacy", message: "Privacy clean moved \(report.moved), failed \(report.failed), skipped \(report.skippedProtected)")
                self.operationLogs.add(
                    category: "privacy",
                    message: "Privacy clean delta: items \(before.items)->\(after.items), bytes \(before.bytes)->\(after.bytes)"
                )
            }
        }
    }

    private func ensureCanScanSelectedTarget() -> Bool {
        applyPermissionDecision(permissionGateUseCase.canScan(target: selectedTarget.url))
    }

    private func ensureCanRunProtectedModule(actionName: String) -> Bool {
        applyPermissionDecision(permissionGateUseCase.canRunProtectedModule(actionName: actionName))
    }

    private func ensureCanModify(urls: [URL], actionName: String, requiresFullDisk: Bool = false) -> Bool {
        applyPermissionDecision(
            permissionGateUseCase.canModify(
                urls: urls,
                actionName: actionName,
                requiresFullDisk: requiresFullDisk
            )
        )
    }

    private func applyPermissionDecision(_ decision: PermissionGateDecision) -> Bool {
        if decision.isAllowed {
            permissionBlockingMessage = nil
            return true
        }
        presentPermissionBlock(
            decision.message ?? "Additional permissions are required for this action."
        )
        return false
    }

    private func presentPermissionBlock(_ message: String) {
        permissionBlockingMessage = message
        operationLogs.add(category: "permissions", message: "Blocked operation: \(message)")
    }

    @discardableResult
    func exportOperationLogReport() -> URL? {
        let url = operationLogs.exportJSON()
        lastExportedOperationLogURL = url
        if let url {
            operationLogs.add(category: "telemetry", message: "Exported operation log report to \(url.path)")
        } else {
            operationLogs.add(category: "telemetry", message: "Failed to export operation log report")
        }
        return url
    }

    @discardableResult
    func exportDiagnosticReport() -> URL? {
        let report = DiagnosticReport(
            generatedAt: Date(),
            selectedTargetPath: selectedTarget.url.path,
            unifiedScanSummary: unifiedScanSummary.map {
                UnifiedScanSnapshot(
                    smartCareCategories: $0.smartCareCategories,
                    smartCareBytes: $0.smartCareBytes,
                    privacyCategories: $0.privacyCategories,
                    privacyBytes: $0.privacyBytes,
                    startupEntries: $0.startupEntries,
                    startupBytes: $0.startupBytes,
                    finishedAt: $0.finishedAt
                )
            },
            smartCareCategoryCount: smartScanCategories.count,
            privacyCategoryCount: privacyCategories.count,
            startupEntryCount: performanceReport?.startupEntries.count ?? 0,
            operationLogs: Array(operationLogs.entries.prefix(300))
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report),
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            operationLogs.add(category: "telemetry", message: "Failed to export diagnostic report")
            return nil
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = downloads.appendingPathComponent("dray-diagnostic-\(stamp).json")
        do {
            try data.write(to: url, options: [.atomic])
            lastExportedDiagnosticURL = url
            operationLogs.add(category: "telemetry", message: "Exported diagnostic report to \(url.path)")
            return url
        } catch {
            operationLogs.add(category: "telemetry", message: "Failed to save diagnostic report")
            return nil
        }
    }

    func revealCrashTelemetry() {
        guard let url = CrashTelemetryService.shared.crashEventsURL() else {
            operationLogs.add(category: "telemetry", message: "Crash telemetry log is empty")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        operationLogs.add(category: "telemetry", message: "Revealed crash telemetry log: \(url.path)")
    }

    private func scan(at url: URL, maxDepth: Int) {
        scanTask?.cancel()
        isLoading = true
        isPaused = false
        progress = ScanProgress(currentPath: url.path, visitedItems: 0)
        AppLogger.scanner.info("Scan started at \(url.path, privacy: .public)")
        scanTask = Task { [weak self] in
            guard let self else { return }
            let selectedAtStart = selectedTarget
            let scanned = await scanner.scan(rootURL: url, maxDepth: maxDepth) { [weak self] progress in
                Task { @MainActor in
                    self?.progress = progress
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.root = scanned
                self.lastScannedTarget = selectedAtStart
                self.isLoading = false
                self.indexStore?.saveSnapshot(root: scanned)
                AppLogger.scanner.info("Scan completed for \(url.path, privacy: .public), visited: \(self.progress.visitedItems)")
            }
        }
    }

    private func scanIncremental(at url: URL, base: FileNode) {
        scanTask?.cancel()
        isLoading = true
        isPaused = false
        progress = ScanProgress(currentPath: url.path, visitedItems: 0)
        AppLogger.scanner.info("Incremental scan started at \(url.path, privacy: .public)")
        scanTask = Task { [weak self] in
            guard let self else { return }
            let selectedAtStart = selectedTarget
            let delta = await scanner.scan(rootURL: url, maxDepth: 2) { [weak self] progress in
                Task { @MainActor in
                    self?.progress = progress
                }
            }
            guard !Task.isCancelled else { return }
            let merged = incrementalTreeMergeUseCase.merge(base: base, delta: delta)
            await MainActor.run {
                self.root = merged
                self.lastScannedTarget = selectedAtStart
                self.isLoading = false
                self.indexStore?.saveSnapshot(root: merged)
                AppLogger.scanner.info("Incremental scan completed for \(url.path, privacy: .public), visited: \(self.progress.visitedItems)")
            }
        }
    }

    func rescan() {
        guard let lastScannedTarget else { return }
        selectedTarget = lastScannedTarget
        scanSelected()
    }

    func restorePermissions() {
        clearSavedTargetBookmark()
        permissions.restorePermissions()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
    }

    func togglePauseScan() {
        isPaused.toggle()
        Task { await scanner.setPaused(isPaused) }
    }

    func cancelScan() {
        scanTask?.cancel()
        Task { await scanner.cancel() }
        isPaused = false
        isLoading = false
        AppLogger.scanner.info("Scan canceled by user")
    }

    func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    func openItem(_ node: FileNode) {
        NSWorkspace.shared.open(node.url)
    }

    func moveToTrash(_ node: FileNode) {
        _ = moveToTrash(nodes: [node])
    }

    func moveToTrash(nodes: [FileNode]) -> TrashOperationResult {
        let outcome = safeFileOperations.moveToTrash(
            nodes: nodes,
            actionName: "Move to Trash",
            canModify: { [weak self] urls, actionName in
                guard let self else { return false }
                return permissions.canModify(urls: urls, actionName: actionName)
            },
            permissionHint: { [weak self] in
                self?.permissions.permissionHint
            }
        )

        for path in outcome.skippedProtected {
            operationLogs.add(
                category: "permissions",
                message: "Skipped system-protected path (SIP): \(path)"
            )
        }
        for failure in outcome.failures {
            if failure.isPermission {
                operationLogs.add(
                    category: "permissions",
                    message: "Blocked trash item: \(failure.path) — \(failure.reason)"
                )
                AppLogger.permissions.error("Blocked trash item by permissions: \(failure.path, privacy: .public)")
            } else {
                operationLogs.add(
                    category: "actions",
                    message: "Failed to move to Trash: \(failure.path) — \(failure.reason)"
                )
                AppLogger.actions.error("Failed to trash item: \(failure.reason, privacy: .public)")
            }
        }
        for movedItem in outcome.moved {
            AppLogger.actions.info("Moved to trash: \(movedItem.originalPath, privacy: .public)")
        }
        recentlyDeleted = recoveryHistoryUseCase.recordMovedItems(
            outcome.moved,
            in: recentlyDeleted
        )

        let moved = outcome.moved.count
        let failed = outcome.failures.map(\.path)

        if moved == 0, !failed.isEmpty, let blockedPermissionHint = outcome.blockedPermissionHint, !blockedPermissionHint.isEmpty {
            presentPermissionBlock(blockedPermissionHint)
        }

        if moved > 0, let lastScannedTarget {
            selectedTarget = lastScannedTarget
            scanSelected()
        }

        return TrashOperationResult(
            moved: moved,
            skippedProtected: outcome.skippedProtected,
            failed: failed
        )
    }

    func trashResultMessage(_ result: TrashOperationResult) -> String {
        let isRussian = appLanguage.localeCode.lowercased().hasPrefix("ru")
        func t(_ ru: String, _ en: String) -> String { isRussian ? ru : en }

        var parts: [String] = [t("Перемещено: \(result.moved)", "Moved: \(result.moved)")]
        if !result.skippedProtected.isEmpty {
            parts.append(t(
                "Пропущено (защищено macOS): \(result.skippedProtected.count)",
                "Skipped (macOS protected): \(result.skippedProtected.count)"
            ))
        }
        if !result.failed.isEmpty {
            parts.append(t("Ошибок: \(result.failed.count)", "Failed: \(result.failed.count)"))
        }

        var message = parts.joined(separator: ", ")

        if !result.skippedProtected.isEmpty {
            message += "\n" + t(
                "Системно-защищённые файлы (SIP/TCC) нельзя удалить обычным приложением, даже при Full Disk Access.",
                "System-protected files (SIP/TCC) cannot be deleted by a regular app, even with Full Disk Access."
            )
            let sampleNames = result.skippedProtected
                .prefix(3)
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
            if !sampleNames.isEmpty {
                message += "\n" + t("Примеры: \(sampleNames)", "Examples: \(sampleNames)")
            }
        }

        if !result.failed.isEmpty {
            let sampleNames = result.failed
                .prefix(3)
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
            if !sampleNames.isEmpty {
                message += "\n" + t("Не удалось удалить: \(sampleNames)", "Could not remove: \(sampleNames)")
            }
        }

        return message
    }

    func restoreDeletedItem(_ item: RecentlyDeletedItem) -> Bool {
        let result = recoveryHistoryUseCase.restore(item: item, from: recentlyDeleted)
        if let failure = result.failures.first {
            AppLogger.actions.error("Failed to restore item: \(failure.reason, privacy: .public)")
            return false
        }
        guard result.restoredCount > 0 else { return false }

        recentlyDeleted = result.history
        if let lastScannedTarget {
            selectedTarget = lastScannedTarget
            scanSelected()
        }
        return true
    }

    func removeDeletedHistoryItem(_ item: RecentlyDeletedItem) {
        recentlyDeleted = recoveryHistoryUseCase.removeHistoryItem(item, from: recentlyDeleted)
    }

    @discardableResult
    func rollbackQuickActionSession(_ session: QuickActionRollbackSession) -> String? {
        guard session.canRollback else { return nil }

        switch session.rollbackKind {
        case .none:
            return nil
        case .restorePriorities:
            let limit = max(5, session.adjustedTargets.count)
            let result = performanceUseCase.restoreAdjustedPriorities(limit: limit)
            activeLoadReliefAdjustments = performanceUseCase.activeAdjustmentsCount
            let summary = "Restored \(result.adjusted.count), failed \(result.failed.count), skipped \(result.skipped.count)"
            updateQuickActionRollbackSession(id: session.id, restoredAt: Date(), summary: summary)
            operationLogs.add(category: "relief", message: "Rollback session restored: \(summary)")
            return summary
        }
    }

    func removeQuickActionRollbackSession(_ session: QuickActionRollbackSession) {
        quickActionRollbackSessions.removeAll { $0.id == session.id }
        saveQuickActionRollbackSessions()
    }

    func saveCurrentSearchPreset(named name: String) {
        let draft = SearchPresetDraft(
            query: searchQuery,
            minSizeMB: minSizeMB,
            pathContains: pathContains,
            ownerContains: ownerContains,
            onlyDirectories: onlyDirectories,
            onlyFiles: onlyFiles,
            useRegex: searchUseRegex,
            depthMin: searchDepthMin,
            depthMax: searchDepthMax,
            modifiedWithinDays: searchModifiedWithinDays > 0 ? searchModifiedWithinDays : nil,
            nodeType: searchNodeType,
            searchMode: searchMode
        )
        searchPresets = searchPresetUseCase.savePreset(
            named: name,
            draft: draft,
            in: searchPresets
        )
    }

    func applySearchPreset(_ preset: SearchPreset) {
        let appliedPreset = searchPresetUseCase.apply(preset)
        searchQuery = appliedPreset.query
        minSizeMB = appliedPreset.minSizeMB
        pathContains = appliedPreset.pathContains
        ownerContains = appliedPreset.ownerContains
        onlyDirectories = appliedPreset.onlyDirectories
        onlyFiles = appliedPreset.onlyFiles
        searchUseRegex = appliedPreset.useRegex
        searchDepthMin = appliedPreset.depthMin
        searchDepthMax = appliedPreset.depthMax
        searchModifiedWithinDays = appliedPreset.modifiedWithinDays
        searchNodeType = appliedPreset.nodeType
        searchMode = appliedPreset.searchMode
        triggerLiveSearch()
    }

    func isPathProtectedForManualCleanup(_ path: String) -> Bool {
        safeFileOperations.isProtectedPath(path)
    }

    func deletePreset(_ preset: SearchPreset) {
        searchPresets = searchPresetUseCase.deletePreset(preset, from: searchPresets)
    }

    private func persistAndResolveBookmark(for url: URL) -> URL? {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: selectedTargetBookmarkKey)

            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return resolvedURL
        } catch {
            return nil
        }
    }

    private func restoreLastTargetIfPossible() {
        guard let data = UserDefaults.standard.data(forKey: selectedTargetBookmarkKey) else { return }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            selectedTarget = ScanTarget(name: url.lastPathComponent, url: url)
        } catch {
            UserDefaults.standard.removeObject(forKey: selectedTargetBookmarkKey)
        }
    }

    private func clearSavedTargetBookmark() {
        UserDefaults.standard.removeObject(forKey: selectedTargetBookmarkKey)
    }

    private func relaunchApp(_ app: InstalledApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
        running.forEach { $0.terminate() }
        _ = NSWorkspace.shared.open(app.appURL)
    }

    private func loadSearchPresets() {
        searchPresets = searchPresetUseCase.loadPresets()
    }

    private func loadRecentlyDeleted() {
        recentlyDeleted = recoveryHistoryUseCase.loadRecentlyDeleted()
    }

    private func loadSmartExclusions() {
        let state = smartExclusionUseCase.loadState()
        smartExclusions = state.excludedPaths
        smartExcludedAnalyzerKeys = state.excludedAnalyzerKeys
    }

    private func loadUninstallSessions() {
        uninstallSessions = uninstallSessionUseCase.load(kind: .uninstall)
    }

    private func loadRepairSessions() {
        repairSessions = uninstallSessionUseCase.load(kind: .repair)
    }

    private func startupTotals(from report: PerformanceReport?) -> (items: Int, bytes: Int64) {
        guard let report else { return (0, 0) }
        return (report.startupEntries.count, report.startupTotalBytes)
    }

    private func privacyTotals(from categories: [PrivacyCategoryState]) -> (items: Int, bytes: Int64) {
        let items = categories.reduce(0) { partial, category in
            partial + category.category.artifacts.count
        }
        let bytes = categories.reduce(Int64.zero) { partial, category in
            partial + category.category.totalBytes
        }
        return (items, bytes)
    }

    private func loadQuickActionRollbackSessions() {
        quickActionRollbackSessions = historyStore.load(
            [QuickActionRollbackSession].self,
            fileName: quickActionRollbackSessionsFileName
        ) ?? []
    }

    private func saveQuickActionRollbackSessions() {
        historyStore.save(
            quickActionRollbackSessions,
            fileName: quickActionRollbackSessionsFileName
        )
    }

    private func appendQuickActionRollbackSession(_ session: QuickActionRollbackSession) {
        quickActionRollbackSessions.insert(session, at: 0)
        if quickActionRollbackSessions.count > 80 {
            quickActionRollbackSessions = Array(quickActionRollbackSessions.prefix(80))
        }
        saveQuickActionRollbackSessions()
    }

    private func recordQuickActionRollbackSession(
        actionTitle: String,
        rollbackKind: QuickActionRollbackKind,
        adjustedTargets: [String],
        beforeItems: Int,
        afterItems: Int
    ) {
        guard rollbackKind != .none, !adjustedTargets.isEmpty else { return }
        let session = QuickActionRollbackSession(
            module: .performance,
            actionTitle: actionTitle,
            rollbackKind: rollbackKind,
            adjustedTargets: adjustedTargets,
            restoredAt: nil,
            rollbackSummary: "State \(beforeItems) -> \(afterItems)"
        )
        appendQuickActionRollbackSession(session)
    }

    private func markLatestQuickRollbackSessionResolved(summary: String) {
        guard let index = quickActionRollbackSessions.firstIndex(where: { $0.canRollback }) else { return }
        quickActionRollbackSessions[index].restoredAt = Date()
        quickActionRollbackSessions[index].rollbackSummary = summary
        saveQuickActionRollbackSessions()
    }

    private func updateQuickActionRollbackSession(id: UUID, restoredAt: Date, summary: String) {
        guard let index = quickActionRollbackSessions.firstIndex(where: { $0.id == id }) else { return }
        quickActionRollbackSessions[index].restoredAt = restoredAt
        quickActionRollbackSessions[index].rollbackSummary = summary
        saveQuickActionRollbackSessions()
    }

}
