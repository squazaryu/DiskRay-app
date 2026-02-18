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

    let permissions = AppPermissionService()

    private let scanner = FileScanner()
    private let queryEngine = QueryEngine()
    private let indexStore = SQLiteIndexStore()
    private let selectedTargetBookmarkKey = "dray.scan.target.bookmark"
    private let searchPresetsKey = "dray.search.presets"
    private let recentlyDeletedKey = "dray.recently.deleted"
    private var scanTask: Task<Void, Never>?
    private let protectedPathPrefixes = ["/System", "/Library", "/bin", "/sbin", "/usr", "/private/var", "/private/etc"]

    init() {
        restoreLastTargetIfPossible()
        loadSearchPresets()
        loadRecentlyDeleted()
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
}
