import Foundation

@MainActor
final class UninstallerFeatureController: ObservableObject {
    @Published private(set) var state = UninstallerFeatureState()

    private let uninstallerUseCase: UninstallerUseCase
    private let uninstallSessionUseCase: UninstallSessionUseCase
    private let uninstallRemainingUseCase: UninstallRemainingUseCase
    private let uninstallObservedAppsUseCase: UninstallObservedAppsUseCase
    private let safeFileOperations: SafeFileOperationService
    private var context: FeatureContext?

    init(
        uninstallerUseCase: UninstallerUseCase,
        uninstallSessionUseCase: UninstallSessionUseCase,
        uninstallRemainingUseCase: UninstallRemainingUseCase,
        uninstallObservedAppsUseCase: UninstallObservedAppsUseCase,
        safeFileOperations: SafeFileOperationService
    ) {
        self.uninstallerUseCase = uninstallerUseCase
        self.uninstallSessionUseCase = uninstallSessionUseCase
        self.uninstallRemainingUseCase = uninstallRemainingUseCase
        self.uninstallObservedAppsUseCase = uninstallObservedAppsUseCase
        self.safeFileOperations = safeFileOperations
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func loadSessions() {
        state.sessions = uninstallSessionUseCase.load(kind: .uninstall)
    }

    func loadRemainingRecords() {
        let loaded = uninstallRemainingUseCase.load()
        state.remainingRecords = uninstallRemainingUseCase.pruneMissing(existing: loaded)
        state.removedAppCandidates = uninstallObservedAppsUseCase.loadRemovedCandidates()
    }

    func refreshRemainingRecords() {
        guard !state.isLoading else { return }
        state.isLoading = true

        let candidates = remainingScanCandidates(
            records: state.remainingRecords,
            sessions: state.sessions,
            removedCandidates: state.removedAppCandidates
        )

        Task { [weak self] in
            guard let self else { return }

            var refreshed: [UninstallRemainingRecord] = []
            for candidate in candidates {
                let app = syntheticInstalledApp(
                    appName: candidate.appName,
                    bundleID: candidate.bundleID
                )
                let remnants = await uninstallerUseCase.findRemnants(for: app)
                guard !remnants.isEmpty else { continue }

                let issues = remnants.map { remnant in
                    UninstallVerifyIssue(
                        url: remnant.url,
                        sizeInBytes: remnant.sizeInBytes,
                        reason: "Detected during scheduled remaining scan.",
                        risk: uninstallerUseCase.repairRisk(for: remnant)
                    )
                }

                refreshed = uninstallRemainingUseCase.upsert(
                    appName: candidate.appName,
                    bundleID: candidate.bundleID,
                    issues: issues,
                    updatedAt: Date(),
                    existing: refreshed
                )
            }

            let pruned = uninstallRemainingUseCase.pruneMissing(existing: refreshed)
            await MainActor.run {
                state.remainingRecords = pruned
                state.isLoading = false
                context?.log(
                    category: "uninstaller",
                    message: "Remaining scan refreshed: apps \(pruned.count), items \(pruned.reduce(0) { $0 + $1.remainingCount })"
                )
            }
        }
    }

    func deepSweepRemainingRecords() {
        guard !state.isLoading else { return }
        state.isLoading = true
        let existingRecords = state.remainingRecords
        let currentInstalled = state.installedApps

        Task { [weak self] in
            guard let self else { return }

            let installedApps: [InstalledApp]
            if currentInstalled.isEmpty {
                installedApps = await uninstallerUseCase.installedApps()
            } else {
                installedApps = currentInstalled
            }

            let candidates = await uninstallerUseCase.deepSweepOrphanRemnants(installedApps: installedApps)
            await MainActor.run {
                state.installedApps = installedApps
                state.remainingRecords = uninstallRemainingUseCase.mergeDeepSweepCandidates(
                    candidates,
                    existing: existingRecords,
                    updatedAt: Date()
                )
                state.isLoading = false
                context?.log(
                    category: "uninstaller",
                    message: "Deep remaining sweep completed: candidates \(candidates.count), apps \(state.remainingRecords.count), items \(state.remainingRecords.reduce(0) { $0 + $1.remainingCount })"
                )
            }
        }
    }

    func loadInstalledApps() {
        state.isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let apps = await uninstallerUseCase.installedApps()
            let removedCandidates = uninstallObservedAppsUseCase.updateObservedApps(currentApps: apps)
            await MainActor.run {
                state.installedApps = apps
                state.removedAppCandidates = removedCandidates
                state.isLoading = false
            }
        }
    }

    func loadRemnants(for app: InstalledApp) {
        state.isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let remnants = await uninstallerUseCase.findRemnants(for: app)
            await MainActor.run {
                state.remnants = remnants
                state.uninstallReport = nil
                state.verifyReport = nil
                state.isLoading = false
            }
        }
    }

    func uninstallPreview(for app: InstalledApp) -> [UninstallPreviewItem] {
        uninstallerUseCase.uninstallPreview(app: app, remnants: state.remnants)
    }

    func uninstall(
        app: InstalledApp,
        selectedItems: [UninstallPreviewItem]? = nil,
        isAppRunning: Bool,
        onFinished: @escaping (_ result: UninstallExecutionResult) -> Void = { _ in }
    ) {
        guard context?.allowProtectedModule("Uninstall") ?? true else { return }
        let preview = uninstallPreview(for: app)
        let items = selectedItems ?? preview
        context?.log(
            category: "uninstaller",
            message: "Uninstall started for \(app.name), items \(items.count)"
        )

        state.isVerifyRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerUseCase.uninstallAndVerify(
                app: app,
                previewItems: items,
                isProtectedPath: { path in
                    safeFileOperations.isProtectedPath(path)
                },
                isAppRunning: isAppRunning
            )
            await MainActor.run {
                state.uninstallReport = result.validation
                state.verifyReport = result.verifyReport
                state.isVerifyRunning = false
                state.sessions = uninstallSessionUseCase.appendSession(
                    from: result.validation,
                    existingSessions: state.sessions,
                    kind: .uninstall
                )
                state.remnants = result.remainingRemnants
                state.remainingRecords = uninstallRemainingUseCase.upsert(
                    appName: app.name,
                    bundleID: app.bundleID,
                    issues: result.verifyReport.remaining,
                    updatedAt: result.verifyReport.createdAt,
                    existing: state.remainingRecords
                )
                context?.log(
                    category: "uninstaller",
                    message: "Uninstall \(app.name): removed \(result.validation.removedCount), skipped \(result.validation.skippedCount), failed \(result.validation.failedCount)"
                )
                onFinished(result)
            }
        }
    }

    func runVerifyPass(
        for app: InstalledApp,
        isAppRunning: Bool
    ) {
        guard context?.allowProtectedModule("Uninstall Verify") ?? true else { return }
        let validation = state.uninstallReport
        let preview = uninstallPreview(for: app)
        state.isVerifyRunning = true
        Task { [weak self] in
            guard let self else { return }
            let result = await uninstallerUseCase.runVerifyPass(
                app: app,
                previewItems: preview,
                validation: validation,
                isProtectedPath: { path in
                    safeFileOperations.isProtectedPath(path)
                },
                isAppRunning: isAppRunning
            )
            await MainActor.run {
                state.remnants = result.remainingRemnants
                state.verifyReport = result.verifyReport
                state.isVerifyRunning = false
                state.remainingRecords = uninstallRemainingUseCase.upsert(
                    appName: app.name,
                    bundleID: app.bundleID,
                    issues: result.verifyReport.remaining,
                    updatedAt: result.verifyReport.createdAt,
                    existing: state.remainingRecords
                )
                context?.log(
                    category: "uninstaller",
                    message: "Verify pass \(app.name): remaining \(result.verifyReport.remainingCount), startup refs \(result.verifyReport.startupReferenceCount)"
                )
            }
        }
    }

    @discardableResult
    func cleanRemainingRecord(_ record: UninstallRemainingRecord) -> TrashOperationResult {
        cleanRemainingIssues(record.issues, actionName: "Uninstall Remaining Cleanup")
    }

    @discardableResult
    func cleanAllRemainingRecords() -> TrashOperationResult {
        cleanRemainingIssues(
            state.remainingRecords.flatMap(\.issues),
            actionName: "Uninstall Remaining Cleanup"
        )
    }

    func removeRemainingRecord(_ record: UninstallRemainingRecord) {
        state.remainingRecords = uninstallRemainingUseCase.removeRecord(
            id: record.id,
            existing: state.remainingRecords
        )
    }

    func clearRemainingRecords() {
        state.remainingRecords = uninstallRemainingUseCase.clear(existing: state.remainingRecords)
    }

    @discardableResult
    func restoreFromSession(_ session: UninstallSession, item: UninstallRollbackItem? = nil) -> UninstallSessionRestoreResult {
        let result = uninstallSessionUseCase.restore(
            from: session,
            item: item,
            sessions: state.sessions,
            kind: .uninstall
        )
        if result.restoredCount > 0 {
            state.sessions = result.sessions
            context?.log(
                category: "uninstaller",
                message: "Rollback restored \(result.restoredCount) item(s) for \(session.appName)"
            )
        }
        if !result.failures.isEmpty {
            context?.log(
                category: "uninstaller",
                message: "Rollback failures for \(session.appName): \(result.failures.count)"
            )
        }
        return result
    }

    private func cleanRemainingIssues(
        _ issues: [UninstallRemainingIssueRecord],
        actionName: String
    ) -> TrashOperationResult {
        let normalizedPaths = Set(
            issues.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path }
        )
        guard !normalizedPaths.isEmpty else {
            return TrashOperationResult(moved: 0, skippedProtected: [], failed: [])
        }

        let existingNodes = normalizedPaths.compactMap(fileNodeForPath)
        let existingPaths = Set(existingNodes.map { $0.url.standardizedFileURL.path })
        let missingPaths = normalizedPaths.subtracting(existingPaths)

        let outcome = safeFileOperations.moveToTrash(
            nodes: existingNodes,
            actionName: actionName,
            canModify: { [weak self] urls, action in
                self?.context?.allowModify(
                    urls: urls,
                    actionName: action,
                    requiresFullDisk: true
                ) ?? true
            },
            permissionHint: {
                "Full Disk Access may be required to remove some remaining artifacts."
            }
        )

        for path in outcome.skippedProtected {
            context?.log(
                category: "permissions",
                message: "Skipped protected remnant path: \(path)"
            )
        }
        for failure in outcome.failures {
            let category = failure.isPermission ? "permissions" : "uninstaller"
            context?.log(
                category: category,
                message: "Failed remaining cleanup: \(failure.path) — \(failure.reason)"
            )
        }

        let resolvedPaths = Set(outcome.moved.map(\.originalPath))
            .union(missingPaths)
        if !resolvedPaths.isEmpty {
            state.remainingRecords = uninstallRemainingUseCase.removePaths(
                resolvedPaths,
                existing: state.remainingRecords
            )
        }

        let result = TrashOperationResult(
            moved: outcome.moved.count,
            skippedProtected: outcome.skippedProtected,
            failed: outcome.failures.map(\.path)
        )

        context?.log(
            category: "uninstaller",
            message: "Remaining cleanup moved \(result.moved), skipped \(result.skippedProtected.count), failed \(result.failed.count), missing \(missingPaths.count)"
        )
        return result
    }

    private func fileNodeForPath(_ path: String) -> FileNode? {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        let url = URL(fileURLWithPath: normalized)
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: normalized, isDirectory: &isDirectory) else {
            return nil
        }
        return FileNode(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDirectory.boolValue,
            sizeInBytes: fileSize(at: url),
            children: []
        )
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
        if let size = values?.totalFileAllocatedSize {
            return Int64(size)
        }
        if let size = values?.fileAllocatedSize {
            return Int64(size)
        }
        if let size = values?.fileSize {
            return Int64(size)
        }
        return 0
    }

    private func remainingScanCandidates(
        records: [UninstallRemainingRecord],
        sessions: [UninstallSession],
        removedCandidates: [UninstallRemovedAppCandidate]
    ) -> [RemainingScanCandidate] {
        var candidates: [RemainingScanCandidate] = []
        var seenByBundle = Set<String>()
        var seenByName = Set<String>()

        for record in records {
            let normalizedName = record.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let bundleID = record.bundleID?.lowercased(), !bundleID.isEmpty {
                guard seenByBundle.insert(bundleID).inserted else { continue }
                seenByName.insert(normalizedName)
                candidates.append(
                    RemainingScanCandidate(appName: record.appName, bundleID: record.bundleID)
                )
            } else {
                guard seenByName.insert(normalizedName).inserted else { continue }
                candidates.append(
                    RemainingScanCandidate(appName: record.appName, bundleID: nil)
                )
            }
        }

        for session in sessions {
            let normalizedName = session.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedName.isEmpty else { continue }
            guard seenByName.insert(normalizedName).inserted else { continue }
            candidates.append(
                RemainingScanCandidate(appName: session.appName, bundleID: nil)
            )
        }

        for removedCandidate in removedCandidates {
            let normalizedName = removedCandidate.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedBundle = removedCandidate.bundleID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if let normalizedBundle, !normalizedBundle.isEmpty {
                guard seenByBundle.insert(normalizedBundle).inserted else { continue }
                seenByName.insert(normalizedName)
                candidates.append(
                    RemainingScanCandidate(
                        appName: removedCandidate.appName,
                        bundleID: removedCandidate.bundleID
                    )
                )
            } else {
                guard seenByName.insert(normalizedName).inserted else { continue }
                candidates.append(
                    RemainingScanCandidate(
                        appName: removedCandidate.appName,
                        bundleID: nil
                    )
                )
            }
        }

        return candidates.sorted {
            $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    private func syntheticInstalledApp(appName: String, bundleID: String?) -> InstalledApp {
        let cleanedName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackID = fallbackBundleID(for: cleanedName)
        let resolvedBundleID = bundleID.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } ?? fallbackID
        let appURL = URL(fileURLWithPath: "/Applications/\(cleanedName).app")
        return InstalledApp(
            name: cleanedName,
            bundleID: resolvedBundleID,
            appURL: appURL
        )
    }

    private func fallbackBundleID(for appName: String) -> String {
        let sanitized = appName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
        return "unknown.\(sanitized.isEmpty ? UUID().uuidString.lowercased() : sanitized)"
    }
}

private struct RemainingScanCandidate {
    let appName: String
    let bundleID: String?
}
