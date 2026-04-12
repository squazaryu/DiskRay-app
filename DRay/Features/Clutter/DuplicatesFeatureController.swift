import Foundation

protocol DuplicateFinding: Sendable {
    func scan(
        roots: [URL],
        minFileSizeBytes: Int64,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) async -> [DuplicateGroup]
}

extension DuplicateFinderService: DuplicateFinding {}

@MainActor
final class DuplicatesFeatureController: ObservableObject {
    @Published private(set) var state: DuplicatesFeatureState

    private let duplicateFinderService: any DuplicateFinding
    private let safeFileOperations: SafeFileOperationService
    private var context: FeatureContext?
    private var scanTask: Task<Void, Never>?

    init(
        state: DuplicatesFeatureState = DuplicatesFeatureState(),
        duplicateFinderService: any DuplicateFinding,
        safeFileOperations: SafeFileOperationService
    ) {
        self.state = state
        self.duplicateFinderService = duplicateFinderService
        self.safeFileOperations = safeFileOperations
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func updateMinSizeMB(_ value: Double) {
        state.minSizeMB = max(1, value)
    }

    func scanDuplicatesInSelectedTarget(_ targetURL: URL) {
        scanDuplicates(roots: [targetURL], targetDescription: targetURL.path)
    }

    func scanDuplicatesInHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        scanDuplicates(roots: [home], targetDescription: home.path)
    }

    func cancelDuplicateScan() {
        scanTask?.cancel()
        state.isScanRunning = false
        state.progress = DuplicateScanProgress(
            phase: "Canceled",
            currentPath: state.progress.currentPath,
            visitedFiles: state.progress.visitedFiles,
            candidateGroups: state.progress.candidateGroups
        )
        context?.log(category: "clutter", message: "Duplicate scan canceled")
    }

    func clearDuplicateResults() {
        state.groups = []
    }

    func moveDuplicatePathsToTrash(
        _ paths: [String],
        onMovedItems: (_ moved: [SafeTrashMove]) -> Void = { _ in },
        onSuccessfulCleanup: () -> Void = {}
    ) -> TrashOperationResult {
        let nodes = paths.compactMap(nodeForPath)
        let missingPaths = Set(paths).subtracting(nodes.map { $0.url.path })

        let outcome = safeFileOperations.moveToTrash(
            nodes: nodes,
            actionName: "Duplicate Cleanup",
            canModify: { [weak self] urls, actionName in
                self?.context?.allowModify(
                    urls: urls,
                    actionName: actionName,
                    requiresFullDisk: false
                ) ?? true
            },
            permissionHint: { nil }
        )

        onMovedItems(outcome.moved)

        for path in outcome.skippedProtected {
            context?.log(category: "permissions", message: "Skipped system-protected path (SIP): \(path)")
        }
        for failure in outcome.failures {
            if failure.isPermission {
                context?.log(
                    category: "permissions",
                    message: "Blocked duplicate cleanup: \(failure.path) — \(failure.reason)"
                )
            } else {
                context?.log(
                    category: "clutter",
                    message: "Failed duplicate cleanup: \(failure.path) — \(failure.reason)"
                )
            }
        }

        let attempted = Set(paths)
        let skipped = Set(outcome.skippedProtected)
        let failed = Set(outcome.failures.map(\.path)).union(missingPaths)
        let movedPaths = attempted.subtracting(skipped).subtracting(failed)

        if !movedPaths.isEmpty {
            state.groups = state.groups.compactMap { group in
                let remaining = group.files.filter { !movedPaths.contains($0.url.path) }
                guard remaining.count > 1 else { return nil }
                return DuplicateGroup(
                    signature: group.signature,
                    files: remaining,
                    sizeInBytes: group.sizeInBytes
                )
            }
            onSuccessfulCleanup()
        }

        let result = TrashOperationResult(
            moved: outcome.moved.count,
            skippedProtected: outcome.skippedProtected,
            failed: Array(failed)
        )
        context?.log(
            category: "clutter",
            message: "Duplicate cleanup moved \(result.moved) file(s), failed \(result.failed.count), skipped \(result.skippedProtected.count)"
        )
        return result
    }

    private func scanDuplicates(roots: [URL], targetDescription: String) {
        scanTask?.cancel()
        state.isScanRunning = true
        state.groups = []
        state.progress = DuplicateScanProgress(
            phase: "Starting",
            currentPath: targetDescription,
            visitedFiles: 0,
            candidateGroups: 0
        )

        let minSizeBytes = Int64(max(1, state.minSizeMB) * 1_048_576)
        context?.log(
            category: "clutter",
            message: "Duplicate scan started for \(targetDescription), min size \(Int(state.minSizeMB)) MB"
        )

        scanTask = Task { [weak self] in
            guard let self else { return }
            let groups = await duplicateFinderService.scan(
                roots: roots,
                minFileSizeBytes: minSizeBytes
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.state.progress = progress
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                state.groups = groups
                state.isScanRunning = false
                state.progress = DuplicateScanProgress(
                    phase: "Completed",
                    currentPath: targetDescription,
                    visitedFiles: state.progress.visitedFiles,
                    candidateGroups: groups.count
                )
                context?.log(
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
}
