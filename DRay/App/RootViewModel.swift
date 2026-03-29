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
        SearchExecutionMode(rawValue: searchModeRaw) ?? .indexed
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
        searchModeRaw = try c.decodeIfPresent(String.self, forKey: .searchModeRaw) ?? SearchExecutionMode.indexed.rawValue
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

struct SmartCategoryState: Identifiable {
    let id: String
    let result: CleanupCategoryResult
    var isSelected: Bool
}

struct PrivacyCategoryState: Identifiable {
    let id: String
    let category: PrivacyCategory
    var isSelected: Bool
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
    case indexed
    case live

    var id: String { rawValue }
    var title: String {
        switch self {
        case .indexed: return "Indexed"
        case .live: return "Live"
        }
    }
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

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var root: FileNode?
    @Published private(set) var isLoading = false
    @Published private(set) var selectedTarget = ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
    @Published private(set) var lastScannedTarget: ScanTarget?
    @Published private(set) var progress = ScanProgress(currentPath: "", visitedItems: 0)
    @Published private(set) var isPaused = false
    @Published var searchQuery = ""
    @Published var minSizeMB: Double = 0
    @Published var pathContains = ""
    @Published var ownerContains = ""
    @Published var onlyDirectories = false
    @Published var onlyFiles = false
    @Published var searchUseRegex = false
    @Published var searchDepthMin = 0
    @Published var searchDepthMax = 12
    @Published var searchModifiedWithinDays = 0
    @Published var searchNodeType: QueryEngine.SearchNodeType = .any
    @Published var searchMode: SearchExecutionMode = .indexed
    @Published private(set) var isLiveSearchRunning = false
    @Published private(set) var liveSearchResults: [FileNode] = []
    @Published private(set) var searchPresets: [SearchPreset] = []
    @Published private(set) var recentlyDeleted: [RecentlyDeletedItem] = []
    @Published var hoveredPath: String?
    @Published private(set) var smartScanCategories: [SmartCategoryState] = []
    @Published private(set) var isSmartScanRunning = false
    @Published private(set) var smartExclusions: [String] = []
    @Published var smartMinCleanSizeMB: Double = 1
    @Published var smartProfile: SmartCleanProfile = .balanced
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var uninstallerRemnants: [AppRemnant] = []
    @Published private(set) var isUninstallerLoading = false
    @Published private(set) var uninstallReport: UninstallValidationReport?
    @Published private(set) var uninstallSessions: [UninstallSession] = []
    @Published private(set) var performanceReport: PerformanceReport?
    @Published private(set) var isPerformanceScanRunning = false
    @Published private(set) var startupCleanupReport: StartupCleanupReport?
    @Published private(set) var privacyCategories: [PrivacyCategoryState] = []
    @Published private(set) var isPrivacyScanRunning = false
    @Published private(set) var privacyCleanReport: PrivacyCleanReport?
    @Published private(set) var lastExportedOperationLogURL: URL?
    @Published private(set) var isUnifiedScanRunning = false
    @Published private(set) var unifiedScanSummary: UnifiedScanSummary?
    @Published private(set) var lastExportedDiagnosticURL: URL?

    let permissions = AppPermissionService()
    let operationLogs = OperationLogStore()

    private let scanner = FileScanner()
    private let smartScanService = SmartScanService()
    private let uninstallerService = AppUninstallerService()
    private let performanceService = PerformanceService()
    private let privacyService = PrivacyService()
    private let queryEngine = QueryEngine()
    private let indexStore = SQLiteIndexStore()
    private let selectedTargetBookmarkKey = "dray.scan.target.bookmark"
    private let searchPresetsKey = "dray.search.presets"
    private let recentlyDeletedKey = "dray.recently.deleted"
    private let smartExclusionsKey = "dray.smart.exclusions"
    private var scanTask: Task<Void, Never>?
    private var liveSearchTask: Task<Void, Never>?
    private let protectedPathPrefixes = ["/System", "/Library", "/bin", "/sbin", "/usr", "/private/var", "/private/etc"]

    init() {
        restoreLastTargetIfPossible()
        loadSearchPresets()
        loadRecentlyDeleted()
        loadSmartExclusions()
        permissions.refreshFolderAccess(for: selectedTarget.url)
    }

    var searchResults: [FileNode] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        if searchMode == .live {
            return liveSearchResults
        }
        guard let root else { return [] }
        return queryEngine.search(
            in: root,
            query: searchQuery,
            minSizeBytes: Int64(minSizeMB * 1_048_576),
            pathContains: pathContains,
            ownerContains: ownerContains,
            onlyDirectories: onlyDirectories,
            onlyFiles: onlyFiles,
            useRegex: searchUseRegex,
            depthMin: searchDepthMin,
            depthMax: max(searchDepthMin, searchDepthMax),
            modifiedWithinDays: searchModifiedWithinDays > 0 ? searchModifiedWithinDays : nil,
            nodeType: searchNodeType
        )
    }

    func triggerLiveSearch() {
        guard searchMode == .live else { return }
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
            let results = self.runLiveSearch(
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
                onlyFiles: onlyFiles
            )
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

    func selectMacDisk() {
        selectedTarget = ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
        clearSavedTargetBookmark()
        permissions.refreshFolderAccess(for: selectedTarget.url)
        triggerLiveSearch()
    }

    func selectHome() {
        let url = FileManager.default.homeDirectoryForCurrentUser
        selectedTarget = ScanTarget(name: "Home", url: url)
        clearSavedTargetBookmark()
        permissions.refreshFolderAccess(for: selectedTarget.url)
        triggerLiveSearch()
    }

    func selectFolder(_ url: URL) {
        let scopedURL = persistAndResolveBookmark(for: url) ?? url
        selectedTarget = ScanTarget(name: scopedURL.lastPathComponent, url: scopedURL)
        permissions.markOnboardingCompleted()
        permissions.refreshFolderAccess(for: selectedTarget.url)
        triggerLiveSearch()
    }

    func scanSelected() {
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
        isSmartScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await smartScanService.runSmartScan(excludedPrefixes: smartExclusions)
            await MainActor.run {
                self.smartScanCategories = result.categories.map {
                    SmartCategoryState(id: $0.key, result: $0, isSelected: $0.isSafeByDefault)
                }
                self.selectRecommendedSmartCategories()
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

        Task { [weak self] in
            guard let self else { return }
            let cleanupResult = await smartScanService.clean(items: items, minSizeBytes: Int64(smartMinCleanSizeMB * 1_048_576))
            await MainActor.run {
                AppLogger.actions.info("Smart clean moved: \(cleanupResult.moved), failed: \(cleanupResult.failed)")
                self.operationLogs.add(category: "smartcare", message: "Smart clean moved \(cleanupResult.moved), failed \(cleanupResult.failed)")
                self.runSmartScan()
            }
        }
    }

    func cleanSmartItems(_ items: [CleanupItem]) {
        guard !items.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let cleanupResult = await smartScanService.clean(items: items, minSizeBytes: Int64(smartMinCleanSizeMB * 1_048_576))
            await MainActor.run {
                AppLogger.actions.info("Smart item clean moved: \(cleanupResult.moved), failed: \(cleanupResult.failed)")
                self.operationLogs.add(category: "smartcare", message: "Smart item clean moved \(cleanupResult.moved), failed \(cleanupResult.failed)")
                self.runSmartScan()
            }
        }
    }

    func selectRecommendedSmartCategories() {
        for index in smartScanCategories.indices {
            let risk = smartScanCategories[index].result.riskLevel
            let safe = smartScanCategories[index].result.isSafeByDefault
            switch smartProfile {
            case .conservative:
                smartScanCategories[index].isSelected = safe && risk == .low
            case .balanced:
                smartScanCategories[index].isSelected = safe && (risk == .low || risk == .medium)
            case .aggressive:
                smartScanCategories[index].isSelected = risk != .high
            }
        }
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
        let normalized = (path as NSString).expandingTildeInPath
        guard !normalized.isEmpty, !smartExclusions.contains(normalized) else { return }
        smartExclusions.append(normalized)
        smartExclusions.sort()
        persistSmartExclusions()
    }

    func loadInstalledApps() {
        isUninstallerLoading = true
        Task { [weak self] in
            guard let self else { return }
            let apps = await uninstallerService.installedApps()
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
            let remnants = await uninstallerService.findRemnants(for: app)
            await MainActor.run {
                self.uninstallerRemnants = remnants
                self.uninstallReport = nil
                self.isUninstallerLoading = false
            }
        }
    }

    func uninstall(app: InstalledApp, selectedItems: [UninstallPreviewItem]? = nil) {
        let preview = uninstallPreview(for: app)
        let items = selectedItems ?? preview
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerService.uninstall(app: app, previewItems: items)
            await MainActor.run {
                AppLogger.actions.info("Uninstall removed: \(result.removedCount), skipped: \(result.skippedCount), failed: \(result.failedCount)")
                self.operationLogs.add(category: "uninstaller", message: "Uninstall \(app.name): removed \(result.removedCount), skipped \(result.skippedCount), failed \(result.failedCount)")
                self.uninstallReport = result
                self.recordUninstallSession(from: result)
                self.uninstallerRemnants = []
                self.loadInstalledApps()
            }
        }
    }

    func restoreFromUninstallSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> Int {
        let targets = item.map { [$0] } ?? session.rollbackItems
        var restored = 0

        for rollback in targets {
            let sourceURL = URL(fileURLWithPath: rollback.trashedPath)
            let originalURL = URL(fileURLWithPath: rollback.originalPath)
            let destinationURL = uniqueRestoreURL(for: originalURL)

            do {
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                restored += 1
            } catch {
                AppLogger.actions.error("Failed uninstall rollback restore: \(error.localizedDescription, privacy: .public)")
            }
        }

        if restored > 0 {
            operationLogs.add(category: "uninstaller", message: "Rollback restored \(restored) item(s) for \(session.appName)")
        }
        return restored
    }

    func uninstallPreview(for app: InstalledApp) -> [UninstallPreviewItem] {
        let appItem = UninstallPreviewItem(
            url: app.appURL,
            type: .appBundle,
            sizeInBytes: 0,
            risk: .high,
            reason: "Main app bundle will be moved to Trash"
        )
        let remnantItems = uninstallerRemnants.map { remnant in
            previewItem(for: remnant)
        }
        return [appItem] + remnantItems.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    func removeSmartExclusion(_ path: String) {
        smartExclusions.removeAll { $0 == path }
        persistSmartExclusions()
    }

    func runPerformanceScan() {
        guard !isPerformanceScanRunning else { return }
        isPerformanceScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let report = await performanceService.buildReport()
            await MainActor.run {
                self.performanceReport = report
                self.startupCleanupReport = nil
                self.isPerformanceScanRunning = false
                self.operationLogs.add(category: "performance", message: "Diagnostics done: startup entries \(report.startupEntries.count)")
            }
        }
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) {
        guard !entries.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let report = await performanceService.cleanupStartupEntries(entries)
            await MainActor.run {
                self.startupCleanupReport = report
                self.operationLogs.add(category: "performance", message: "Startup cleanup moved \(report.moved), failed \(report.failed), skipped \(report.skippedProtected)")
                self.runPerformanceScan()
            }
        }
    }

    func runPrivacyScan() {
        guard !isPrivacyScanRunning else { return }
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
        isUnifiedScanRunning = true
        operationLogs.add(category: "scan", message: "Unified scan started")

        Task { [weak self] in
            guard let self else { return }
            async let smartResult = smartScanService.runSmartScan(excludedPrefixes: smartExclusions)
            async let privacyResult = privacyService.runScan()
            async let performanceResult = performanceService.buildReport()

            let (smart, privacy, performance) = await (smartResult, privacyResult, performanceResult)

            await MainActor.run {
                self.smartScanCategories = smart.categories.map {
                    SmartCategoryState(id: $0.key, result: $0, isSelected: $0.isSafeByDefault)
                }
                self.selectRecommendedSmartCategories()

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

    func cleanSelectedPrivacyCategories() {
        let artifacts = privacyCategories
            .filter(\.isSelected)
            .flatMap(\.category.artifacts)
        guard !artifacts.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            let report = await privacyService.clean(artifacts: artifacts)
            await MainActor.run {
                self.privacyCleanReport = report
                self.operationLogs.add(category: "privacy", message: "Privacy clean moved \(report.moved), failed \(report.failed), skipped \(report.skippedProtected)")
                self.runPrivacyScan()
            }
        }
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
            let merged = mergeIncremental(base: base, delta: delta)
            await MainActor.run {
                self.root = merged
                self.lastScannedTarget = selectedAtStart
                self.isLoading = false
                self.indexStore?.saveSnapshot(root: merged)
                AppLogger.scanner.info("Incremental scan completed for \(url.path, privacy: .public), visited: \(self.progress.visitedItems)")
            }
        }
    }

    private func mergeIncremental(base: FileNode, delta: FileNode) -> FileNode {
        var byPath = Dictionary(uniqueKeysWithValues: base.children.map { ($0.url.path, $0) })
        for updated in delta.children {
            if updated.url.path == base.url.path { continue }
            if let existing = byPath[updated.url.path] {
                byPath[updated.url.path] = mergeNode(existing: existing, updated: updated)
            } else {
                byPath[updated.url.path] = updated
            }
        }
        let children = Array(byPath.values).sorted { $0.sizeInBytes > $1.sizeInBytes }
        let total = children.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return FileNode(
            url: base.url,
            name: base.name,
            isDirectory: true,
            sizeInBytes: total,
            children: children
        )
    }

    private func mergeChildrenByPath(base: [FileNode], delta: [FileNode]) -> [FileNode] {
        var byPath = Dictionary(uniqueKeysWithValues: base.map { ($0.url.path, $0) })
        for node in delta {
            if let existing = byPath[node.url.path] {
                byPath[node.url.path] = mergeNode(existing: existing, updated: node)
            } else {
                byPath[node.url.path] = node
            }
        }
        return Array(byPath.values).sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func mergeNode(existing: FileNode, updated: FileNode) -> FileNode {
        let mergedChildren = mergeChildrenByPath(base: existing.children, delta: updated.children)
        let mergedSize = updated.sizeInBytes > 0 ? updated.sizeInBytes : existing.sizeInBytes
        return FileNode(
            url: existing.url,
            name: existing.name,
            isDirectory: existing.isDirectory,
            sizeInBytes: mergedSize,
            children: mergedChildren
        )
    }

    func rescan() {
        guard let lastScannedTarget else { return }
        selectedTarget = lastScannedTarget
        scanSelected()
    }

    func restorePermissions() {
        clearSavedTargetBookmark()
        permissions.restorePermissions()
        permissions.refreshFolderAccess(for: selectedTarget.url)
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
        var moved = 0
        var skippedProtected: [String] = []
        var failed: [String] = []

        for node in nodes {
            if isProtectedPath(node.url.path) {
                skippedProtected.append(node.url.path)
                continue
            }
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: node.url, resultingItemURL: &trashedURL)
                moved += 1
                AppLogger.actions.info("Moved to trash: \(node.url.path, privacy: .public)")
                if let trashedPath = (trashedURL as URL?)?.path {
                    addRecentlyDeleted(originalPath: node.url.path, trashedPath: trashedPath)
                }
            } catch {
                failed.append(node.url.path)
                AppLogger.actions.error("Failed to trash item: \(error.localizedDescription, privacy: .public)")
            }
        }

        if moved > 0, let lastScannedTarget {
            selectedTarget = lastScannedTarget
            scanSelected()
        }

        return TrashOperationResult(moved: moved, skippedProtected: skippedProtected, failed: failed)
    }

    func restoreDeletedItem(_ item: RecentlyDeletedItem) -> Bool {
        let sourceURL = URL(fileURLWithPath: item.trashedPath)
        let originalURL = URL(fileURLWithPath: item.originalPath)
        let destinationURL = uniqueRestoreURL(for: originalURL)

        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            recentlyDeleted.removeAll { $0.id == item.id }
            persistRecentlyDeleted()
            if let lastScannedTarget {
                selectedTarget = lastScannedTarget
                scanSelected()
            }
            return true
        } catch {
            AppLogger.actions.error("Failed to restore item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func removeDeletedHistoryItem(_ item: RecentlyDeletedItem) {
        recentlyDeleted.removeAll { $0.id == item.id }
        persistRecentlyDeleted()
    }

    func saveCurrentSearchPreset(named name: String) {
        let preset = SearchPreset(
            id: UUID(),
            name: name,
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
        searchPresets.insert(preset, at: 0)
        persistSearchPresets()
    }

    func applySearchPreset(_ preset: SearchPreset) {
        searchQuery = preset.query
        minSizeMB = preset.minSizeMB
        pathContains = preset.pathContains
        ownerContains = preset.ownerContains
        onlyDirectories = preset.onlyDirectories
        onlyFiles = preset.onlyFiles
        searchUseRegex = preset.useRegex
        searchDepthMin = preset.depthMin
        searchDepthMax = preset.depthMax
        searchModifiedWithinDays = preset.modifiedWithinDays ?? 0
        searchNodeType = preset.nodeType
        searchMode = preset.searchMode
        triggerLiveSearch()
    }

    func deletePreset(_ preset: SearchPreset) {
        searchPresets.removeAll { $0.id == preset.id }
        persistSearchPresets()
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

    private func loadSearchPresets() {
        guard let data = UserDefaults.standard.data(forKey: searchPresetsKey),
              let presets = try? JSONDecoder().decode([SearchPreset].self, from: data) else { return }
        searchPresets = presets
    }

    private func persistSearchPresets() {
        guard let data = try? JSONEncoder().encode(searchPresets) else { return }
        UserDefaults.standard.set(data, forKey: searchPresetsKey)
    }

    private func addRecentlyDeleted(originalPath: String, trashedPath: String) {
        let item = RecentlyDeletedItem(
            id: UUID(),
            originalPath: originalPath,
            trashedPath: trashedPath,
            deletedAt: Date()
        )
        recentlyDeleted.insert(item, at: 0)
        if recentlyDeleted.count > 200 {
            recentlyDeleted = Array(recentlyDeleted.prefix(200))
        }
        persistRecentlyDeleted()
    }

    private func recordUninstallSession(from report: UninstallValidationReport) {
        let rollbackItems = report.results.compactMap { result -> UninstallRollbackItem? in
            guard result.status == .removed, let trashedPath = result.trashedPath else { return nil }
            return UninstallRollbackItem(
                originalPath: result.url.path,
                trashedPath: trashedPath,
                type: result.type
            )
        }
        guard !rollbackItems.isEmpty else { return }
        let session = UninstallSession(appName: report.appName, createdAt: report.createdAt, rollbackItems: rollbackItems)
        uninstallSessions.insert(session, at: 0)
        if uninstallSessions.count > 50 {
            uninstallSessions = Array(uninstallSessions.prefix(50))
        }
    }

    private func loadRecentlyDeleted() {
        guard let data = UserDefaults.standard.data(forKey: recentlyDeletedKey),
              let items = try? JSONDecoder().decode([RecentlyDeletedItem].self, from: data) else { return }
        recentlyDeleted = items
    }

    private func persistRecentlyDeleted() {
        guard let data = try? JSONEncoder().encode(recentlyDeleted) else { return }
        UserDefaults.standard.set(data, forKey: recentlyDeletedKey)
    }

    private func loadSmartExclusions() {
        smartExclusions = UserDefaults.standard.stringArray(forKey: smartExclusionsKey) ?? []
    }

    private func persistSmartExclusions() {
        UserDefaults.standard.set(smartExclusions, forKey: smartExclusionsKey)
    }

    private func uniqueRestoreURL(for desiredURL: URL) -> URL {
        if !FileManager.default.fileExists(atPath: desiredURL.path) { return desiredURL }

        let folder = desiredURL.deletingLastPathComponent()
        let ext = desiredURL.pathExtension
        let base = desiredURL.deletingPathExtension().lastPathComponent
        var idx = 1

        while idx < 10_000 {
            let candidateName = ext.isEmpty ? "\(base) (\(idx))" : "\(base) (\(idx)).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            idx += 1
        }
        return folder.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
    }

    private func isProtectedPath(_ path: String) -> Bool {
        if path == "/" { return true }
        return protectedPathPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private func runLiveSearch(
        rootURL: URL,
        query: String,
        useRegex: Bool,
        pathContains: String,
        ownerContains: String,
        minSizeBytes: Int64,
        depthMin: Int,
        depthMax: Int,
        modifiedWithinDays: Int?,
        nodeType: QueryEngine.SearchNodeType,
        onlyDirectories: Bool,
        onlyFiles: Bool
    ) -> [FileNode] {
        let started = rootURL.startAccessingSecurityScopedResource()
        defer {
            if started { rootURL.stopAccessingSecurityScopedResource() }
        }

        let regex = useRegex ? (try? NSRegularExpression(pattern: query, options: [.caseInsensitive])) : nil
        let cutoff: Date? = modifiedWithinDays.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? .distantPast }
        let rootComponents = rootURL.pathComponents.count
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [FileNode] = []
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            let depth = max(0, fileURL.pathComponents.count - rootComponents)
            if depth > depthMax {
                enumerator.skipDescendants()
                continue
            }
            if depth < depthMin { continue }

            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                continue
            }
            let isDir = values.isDirectory == true
            let size = Int64(values.fileSize ?? 0)

            let queryMatch: Bool
            if let regex {
                let text = fileURL.path
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                queryMatch = regex.firstMatch(in: text, options: [], range: range) != nil
            } else {
                let lower = query.lowercased()
                queryMatch = fileURL.lastPathComponent.lowercased().contains(lower) || fileURL.path.lowercased().contains(lower)
            }
            guard queryMatch else { continue }
            guard pathContains.isEmpty || fileURL.path.lowercased().contains(pathContains) else { continue }

            if !ownerContains.isEmpty {
                let owner = (try? fm.attributesOfItem(atPath: fileURL.path)[.ownerAccountName] as? String) ?? ""
                guard owner.lowercased().contains(ownerContains) else { continue }
            }
            guard size >= minSizeBytes else { continue }
            if let cutoff, let modified = values.contentModificationDate {
                guard modified >= cutoff else { continue }
            } else if cutoff != nil {
                continue
            }
            guard (!onlyDirectories || isDir) && (!onlyFiles || !isDir) else { continue }
            guard matchesNodeTypeLive(isDirectory: isDir, url: fileURL, nodeType: nodeType) else { continue }

            results.append(FileNode(
                url: fileURL,
                name: fileURL.lastPathComponent,
                isDirectory: isDir,
                sizeInBytes: size,
                children: []
            ))
            if results.count >= 300 { break }
        }

        return results.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func matchesNodeTypeLive(isDirectory: Bool, url: URL, nodeType: QueryEngine.SearchNodeType) -> Bool {
        switch nodeType {
        case .any: return true
        case .file: return !isDirectory
        case .directory: return isDirectory
        case .package: return isDirectory && url.pathExtension == "app"
        }
    }

    private func previewItem(for remnant: AppRemnant) -> UninstallPreviewItem {
        let path = remnant.url.path
        if path.contains("/Library/LaunchDaemons") || path.contains("/Library/PrivilegedHelperTools") {
            return UninstallPreviewItem(
                url: remnant.url,
                type: .remnant,
                sizeInBytes: remnant.sizeInBytes,
                risk: .high,
                reason: "System-level helper or daemon"
            )
        }
        if path.contains("/Library/LaunchAgents") || path.contains("/Library/StartupItems") {
            return UninstallPreviewItem(
                url: remnant.url,
                type: .remnant,
                sizeInBytes: remnant.sizeInBytes,
                risk: .medium,
                reason: "Auto-start component"
            )
        }
        return UninstallPreviewItem(
            url: remnant.url,
            type: .remnant,
            sizeInBytes: remnant.sizeInBytes,
            risk: .low,
            reason: "Regular app support/caches/logs"
        )
    }
}
