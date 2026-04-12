import Foundation
import AppKit
import Combine

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
    let scopeModeRaw: String
    let scopePath: String?
    let excludeTrash: Bool
    let includeHidden: Bool
    let includePackageContents: Bool

    var nodeType: QueryEngine.SearchNodeType {
        QueryEngine.SearchNodeType(rawValue: nodeTypeRaw) ?? .any
    }

    var searchMode: SearchExecutionMode {
        SearchExecutionMode(rawValue: searchModeRaw) ?? .live
    }

    var scopeMode: SearchScopeMode {
        SearchScopeMode(rawValue: scopeModeRaw) ?? .startupDisk
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
        searchMode: SearchExecutionMode,
        scopeMode: SearchScopeMode = .startupDisk,
        scopePath: String? = nil,
        excludeTrash: Bool = true,
        includeHidden: Bool = true,
        includePackageContents: Bool = true
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
        self.scopeModeRaw = scopeMode.rawValue
        self.scopePath = scopePath
        self.excludeTrash = excludeTrash
        self.includeHidden = includeHidden
        self.includePackageContents = includePackageContents
    }

    enum CodingKeys: String, CodingKey {
        case id, name, query, minSizeMB, pathContains, ownerContains, onlyDirectories, onlyFiles
        case useRegex, depthMin, depthMax, modifiedWithinDays, nodeTypeRaw, searchModeRaw
        case scopeModeRaw, scopePath, excludeTrash, includeHidden, includePackageContents
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
        scopeModeRaw = try c.decodeIfPresent(String.self, forKey: .scopeModeRaw) ?? SearchScopeMode.startupDisk.rawValue
        scopePath = try c.decodeIfPresent(String.self, forKey: .scopePath)
        excludeTrash = try c.decodeIfPresent(Bool.self, forKey: .excludeTrash) ?? true
        includeHidden = try c.decodeIfPresent(Bool.self, forKey: .includeHidden) ?? true
        includePackageContents = try c.decodeIfPresent(Bool.self, forKey: .includePackageContents) ?? true
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

enum SearchScopeMode: String, CaseIterable, Identifiable, Codable {
    case startupDisk
    case selectedTarget
    case customPath

    var id: String { rawValue }
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
    let search: SearchFeatureController
    let recovery: RecoveryFeatureController
    @Published var hoveredPath: String?
    let smartCareController: SmartCareFeatureController
    let uninstaller: UninstallerFeatureController
    let repair: RepairFeatureController
    let performanceController: PerformanceFeatureController
    let duplicatesController: DuplicatesFeatureController
    let privacy: PrivacyFeatureController
    @Published private(set) var lastExportedOperationLogURL: URL?
    @Published private(set) var isUnifiedScanRunning = false
    @Published private(set) var unifiedScanSummary: UnifiedScanSummary?
    @Published private(set) var lastExportedDiagnosticURL: URL?
    @Published var permissionBlockingMessage: String?
    @Published private(set) var launchAtLoginEnabled = false
    @Published var appLanguage: AppLanguage = .system {
        didSet {
            uiSettingsStore.saveAppLanguage(appLanguage)
        }
    }
    @Published var appAppearance: AppAppearance = .system {
        didSet {
            uiSettingsStore.saveAppAppearance(appAppearance)
        }
    }

    let permissions: AppPermissionService
    let operationLogs: OperationLogStore

    private let scanner: FileScanner
    private let incrementalTreeMergeUseCase: IncrementalTreeMergeUseCase
    private let permissionGateUseCase: PermissionGateUseCase
    private let privacyService: PrivacyService
    private let menuBarLoginAgentService: MenuBarLoginAgentService
    private let indexStore: SQLiteIndexStore?
    private let safeFileOperations: SafeFileOperationService
    private let uiSettingsStore: any UISettingsStoring
    private var scanTask: Task<Void, Never>?
    private var featureStateCancellables = Set<AnyCancellable>()

    init(initialSection: AppSection? = nil, dependencies: RootViewModelDependencies = .live) {
        self.permissions = dependencies.permissions
        self.operationLogs = dependencies.operationLogs
        self.scanner = dependencies.scanner
        self.incrementalTreeMergeUseCase = IncrementalTreeMergeUseCase()
        self.permissionGateUseCase = PermissionGateUseCase(service: dependencies.permissions)
        let uninstallerUseCase = UninstallerUseCase(service: dependencies.uninstallerService)
        let smartCareUseCase = SmartCareUseCase(service: dependencies.smartScanService)
        let smartExclusionUseCase = SmartExclusionUseCase()
        self.smartCareController = SmartCareFeatureController(
            smartCareUseCase: smartCareUseCase,
            smartExclusionUseCase: smartExclusionUseCase
        )
        let performanceUseCase = PerformanceUseCase(
            performanceService: dependencies.performanceService,
            processPriorityService: dependencies.processPriorityService,
            batteryEnergyService: BatteryEnergyService(
                batteryDiagnosticsService: dependencies.batteryDiagnosticsService,
                energyConsumersService: EnergyConsumersService(),
                attributionEstimator: BatteryAttributionEstimator()
            )
        )
        self.performanceController = PerformanceFeatureController(useCase: performanceUseCase)
        self.privacyService = dependencies.privacyService
        self.menuBarLoginAgentService = dependencies.menuBarLoginAgentService
        self.indexStore = dependencies.indexStore
        self.safeFileOperations = dependencies.safeFileOperations
        self.uiSettingsStore = dependencies.uiSettingsStore
        self.duplicatesController = DuplicatesFeatureController(
            duplicateFinderService: dependencies.duplicateFinderService,
            safeFileOperations: dependencies.safeFileOperations
        )
        let searchPresetUseCase = SearchPresetUseCase(store: dependencies.searchPresetStore)
        self.search = SearchFeatureController(
            selectedTargetURL: URL(fileURLWithPath: "/"),
            liveSearchService: dependencies.liveSearchService,
            searchPresetUseCase: searchPresetUseCase
        )
        self.privacy = PrivacyFeatureController(privacyService: dependencies.privacyService)
        let uninstallSessionUseCase = UninstallSessionUseCase(
            historyStore: dependencies.historyStore,
            safeFileOperations: dependencies.safeFileOperations
        )
        self.uninstaller = UninstallerFeatureController(
            uninstallerUseCase: uninstallerUseCase,
            uninstallSessionUseCase: uninstallSessionUseCase,
            safeFileOperations: dependencies.safeFileOperations
        )
        self.repair = RepairFeatureController(
            uninstallerUseCase: uninstallerUseCase,
            uninstallSessionUseCase: uninstallSessionUseCase
        )
        self.recovery = RecoveryFeatureController(
            recoveryHistoryUseCase: RecoveryHistoryUseCase(
                historyStore: dependencies.historyStore,
                safeFileOperations: dependencies.safeFileOperations
            ),
            recoveryStore: dependencies.recoveryStore
        )

        if let language = uiSettingsStore.loadAppLanguage() {
            appLanguage = language
        }
        if let appearance = uiSettingsStore.loadAppAppearance() {
            appAppearance = appearance
        }
        restoreLastTargetIfPossible()
        search.setSelectedTargetURL(selectedTarget.url)
        search.loadPresets()
        recovery.loadHistory()
        smartCareController.loadExclusions()
        uninstaller.loadSessions()
        repair.loadSessions()
        refreshLaunchAtLoginStatus()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        if let initialSection {
            selectedSection = initialSection
        }

        search.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        smartCareController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        duplicatesController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        privacy.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        recovery.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        uninstaller.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        repair.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)
        performanceController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &featureStateCancellables)

        let context = FeatureContext(
            canRunProtectedModule: { [weak self] actionName in
                guard let self else {
                    return .blocked("Internal state is unavailable. Reopen DRay and retry.")
                }
                return self.permissionGateUseCase.canRunProtectedModule(actionName: actionName)
            },
            canModify: { [weak self] urls, actionName, requiresFullDisk in
                guard let self else {
                    return .blocked("Internal state is unavailable. Reopen DRay and retry.")
                }
                return self.permissionGateUseCase.canModify(
                    urls: urls,
                    actionName: actionName,
                    requiresFullDisk: requiresFullDisk
                )
            },
            presentPermissionBlock: { [weak self] message in
                self?.presentPermissionBlock(message)
            },
            addOperationLog: { [weak self] category, message in
                self?.operationLogs.add(category: category, message: message)
            }
        )
        smartCareController.attachContext(context)
        duplicatesController.attachContext(context)
        privacy.attachContext(context)
        performanceController.attachContext(context)
        uninstaller.attachContext(context)
        repair.attachContext(context)
    }

    var performance: PerformanceFeatureState {
        performanceController.state
    }

    var performanceQuickActionDelta: QuickActionDeltaReport? {
        performanceController.state.quickActionDelta
    }

    var performanceReport: PerformanceReport? {
        performanceController.state.report
    }

    private var isPerformanceScanRunning: Bool {
        performanceController.state.isScanRunning
    }

    private var activeLoadReliefAdjustments: Int {
        performanceController.state.activeLoadReliefAdjustments
    }

    var privacyCategories: [PrivacyCategoryState] {
        privacy.state.categories
    }

    var recentlyDeleted: [RecentlyDeletedItem] {
        recovery.state.recentlyDeleted
    }

    var quickActionRollbackSessions: [QuickActionRollbackSession] {
        recovery.state.quickActionRollbackSessions
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
        let result = performanceController.reduceCPULoad(consumers: consumers, limit: limit)
        recordQuickActionRollbackSession(
            actionTitle: "Reduce CPU",
            rollbackKind: .restorePriorities,
            adjustedTargets: result.adjusted,
            beforeItems: beforeAdjustments,
            afterItems: activeLoadReliefAdjustments
        )
        return result
    }

    func reduceMemoryLoad(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        let beforeAdjustments = activeLoadReliefAdjustments
        let result = performanceController.reduceMemoryLoad(consumers: consumers, limit: limit)
        recordQuickActionRollbackSession(
            actionTitle: "Reduce Memory",
            rollbackKind: .restorePriorities,
            adjustedTargets: result.adjusted,
            beforeItems: beforeAdjustments,
            afterItems: activeLoadReliefAdjustments
        )
        return result
    }

    func restoreAdjustedProcessPriorities(limit: Int = 5) -> LoadReliefResult {
        let result = performanceController.restoreAdjustedPriorities(limit: limit)
        markLatestQuickRollbackSessionResolved(
            summary: "Restored \(result.adjusted.count), failed \(result.failed.count), skipped \(result.skipped.count)"
        )
        return result
    }

    func selectMacDisk() {
        selectedTarget = ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
        clearSavedTargetBookmark()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        search.setSelectedTargetURL(selectedTarget.url)
        search.runSearch()
    }

    func selectHome() {
        let url = FileManager.default.homeDirectoryForCurrentUser
        selectedTarget = ScanTarget(name: "Home", url: url)
        clearSavedTargetBookmark()
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        search.setSelectedTargetURL(selectedTarget.url)
        search.runSearch()
    }

    func selectFolder(_ url: URL) {
        let scopedURL = persistAndResolveBookmark(for: url) ?? url
        selectedTarget = ScanTarget(name: scopedURL.lastPathComponent, url: scopedURL)
        permissions.refreshPermissionStatus(for: selectedTarget.url)
        if permissions.hasFolderPermission && permissions.hasFullDiskAccess {
            permissions.markOnboardingCompleted()
        }
        search.setSelectedTargetURL(selectedTarget.url)
        search.runSearch()
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

    func runPerformanceScan() {
        guard !isPerformanceScanRunning else { return }
        performanceController.runDiagnostics()
    }

    func runPrivacyScan() {
        privacy.runScan()
    }

    func runUnifiedScan() {
        guard !isUnifiedScanRunning else { return }
        guard ensureCanRunProtectedModule(actionName: "Unified Scan") else { return }
        isUnifiedScanRunning = true
        operationLogs.add(category: "scan", message: "Unified scan started")

        Task { [weak self] in
            guard let self else { return }
            async let smartResult = smartCareController.runScanSnapshot()
            async let privacyResult = privacyService.runScan()
            async let performanceResult = performanceController.runDiagnosticsSnapshot()

            let (smart, privacy, performance) = await (smartResult, privacyResult, performanceResult)

            await MainActor.run {
                self.smartCareController.applySmartScanResult(smart)

                self.privacy.applyScanResult(privacy)

                self.performanceController.applyDiagnosticsReport(
                    performance,
                    clearStartupCleanup: true
                )

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

    private func ensureCanScanSelectedTarget() -> Bool {
        applyPermissionDecision(permissionGateUseCase.canScan(target: selectedTarget.url))
    }

    private func ensureCanRunProtectedModule(actionName: String) -> Bool {
        applyPermissionDecision(permissionGateUseCase.canRunProtectedModule(actionName: actionName))
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
            smartCareCategoryCount: smartCareController.state.categories.count,
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
        recovery.recordMovedItems(outcome.moved)

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
        let result = recovery.restore(item: item)
        if let failure = result.failures.first {
            AppLogger.actions.error("Failed to restore item: \(failure.reason, privacy: .public)")
            return false
        }
        guard result.restoredCount > 0 else { return false }
        if let lastScannedTarget {
            selectedTarget = lastScannedTarget
            scanSelected()
        }
        return true
    }

    func removeDeletedHistoryItem(_ item: RecentlyDeletedItem) {
        recovery.removeHistoryItem(item)
    }

    @discardableResult
    func rollbackQuickActionSession(_ session: QuickActionRollbackSession) -> String? {
        let summary = recovery.restoreSession(session) { [weak self] limit in
            guard let self else {
                return LoadReliefResult(adjusted: [], skipped: [], failed: ["internal-state-unavailable"])
            }
            return self.performanceController.restoreAdjustedPriorities(limit: limit)
        }
        if let summary {
            operationLogs.add(category: "relief", message: "Rollback session restored: \(summary)")
        }
        return summary
    }

    func removeQuickActionRollbackSession(_ session: QuickActionRollbackSession) {
        recovery.removeRollbackSession(session)
    }

    func isPathProtectedForManualCleanup(_ path: String) -> Bool {
        safeFileOperations.isProtectedPath(path)
    }

    private func persistAndResolveBookmark(for url: URL) -> URL? {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            uiSettingsStore.saveSelectedTargetBookmark(bookmark)

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
        guard let data = uiSettingsStore.loadSelectedTargetBookmark() else { return }
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
            uiSettingsStore.clearSelectedTargetBookmark()
        }
    }

    private func clearSavedTargetBookmark() {
        uiSettingsStore.clearSelectedTargetBookmark()
    }

    private func appendQuickActionRollbackSession(_ session: QuickActionRollbackSession) {
        recovery.appendRollbackSession(session)
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
        recovery.markLatestRollbackSessionResolved(summary: summary)
    }

}
