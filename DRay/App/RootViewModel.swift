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
    let onlyDirectories: Bool
    let onlyFiles: Bool
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
    @Published var onlyDirectories = false
    @Published var onlyFiles = false
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

    let permissions = AppPermissionService()

    private let scanner = FileScanner()
    private let smartScanService = SmartScanService()
    private let uninstallerService = AppUninstallerService()
    private let queryEngine = QueryEngine()
    private let indexStore = SQLiteIndexStore()
    private let selectedTargetBookmarkKey = "dray.scan.target.bookmark"
    private let searchPresetsKey = "dray.search.presets"
    private let recentlyDeletedKey = "dray.recently.deleted"
    private let smartExclusionsKey = "dray.smart.exclusions"
    private var scanTask: Task<Void, Never>?
    private let protectedPathPrefixes = ["/System", "/Library", "/bin", "/sbin", "/usr", "/private/var", "/private/etc"]

    init() {
        restoreLastTargetIfPossible()
        loadSearchPresets()
        loadRecentlyDeleted()
        loadSmartExclusions()
        permissions.refreshFolderAccess(for: selectedTarget.url)
    }

    var searchResults: [FileNode] {
        guard let root else { return [] }
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return queryEngine.search(
            in: root,
            query: searchQuery,
            minSizeBytes: Int64(minSizeMB * 1_048_576),
            pathContains: pathContains,
            onlyDirectories: onlyDirectories,
            onlyFiles: onlyFiles
        )
    }

    var selectedTargetPath: String {
        selectedTarget.url.path
    }

    func selectMacDisk() {
        selectedTarget = ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
        clearSavedTargetBookmark()
        permissions.refreshFolderAccess(for: selectedTarget.url)
    }

    func selectHome() {
        let url = FileManager.default.homeDirectoryForCurrentUser
        selectedTarget = ScanTarget(name: "Home", url: url)
        clearSavedTargetBookmark()
        permissions.refreshFolderAccess(for: selectedTarget.url)
    }

    func selectFolder(_ url: URL) {
        let scopedURL = persistAndResolveBookmark(for: url) ?? url
        selectedTarget = ScanTarget(name: scopedURL.lastPathComponent, url: scopedURL)
        permissions.markOnboardingCompleted()
        permissions.refreshFolderAccess(for: selectedTarget.url)
    }

    func scanSelected() {
        if let cached = indexStore?.loadSnapshot(rootPath: selectedTarget.url.path) {
            root = cached
        }
        scan(at: selectedTarget.url)
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

    func uninstall(app: InstalledApp) {
        let remnants = uninstallerRemnants
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerService.uninstall(app: app, remnants: remnants)
            await MainActor.run {
                AppLogger.actions.info("Uninstall removed: \(result.removedCount), skipped: \(result.skippedCount), failed: \(result.failedCount)")
                self.uninstallReport = result
                self.uninstallerRemnants = []
                self.loadInstalledApps()
            }
        }
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

    private func scan(at url: URL) {
        scanTask?.cancel()
        isLoading = true
        isPaused = false
        progress = ScanProgress(currentPath: url.path, visitedItems: 0)
        AppLogger.scanner.info("Scan started at \(url.path, privacy: .public)")
        scanTask = Task { [weak self] in
            guard let self else { return }
            let selectedAtStart = selectedTarget
            let scanned = await scanner.scan(rootURL: url, maxDepth: 7) { [weak self] progress in
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
            onlyDirectories: onlyDirectories,
            onlyFiles: onlyFiles
        )
        searchPresets.insert(preset, at: 0)
        persistSearchPresets()
    }

    func applySearchPreset(_ preset: SearchPreset) {
        searchQuery = preset.query
        minSizeMB = preset.minSizeMB
        pathContains = preset.pathContains
        onlyDirectories = preset.onlyDirectories
        onlyFiles = preset.onlyFiles
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
