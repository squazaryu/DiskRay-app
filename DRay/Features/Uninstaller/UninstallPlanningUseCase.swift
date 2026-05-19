import Foundation

struct UninstallPlanningUseCase {
    func repairRisk(for remnant: AppRemnant) -> UninstallRiskLevel {
        previewItem(for: remnant).risk
    }

    func uninstallPreview(app: InstalledApp, remnants: [AppRemnant], mode: UninstallMode) -> [UninstallPreviewItem] {
        let appItem = UninstallPreviewItem(
            url: app.appURL,
            type: .appBundle,
            sizeInBytes: 0,
            risk: .high,
            reason: mode == .clean
                ? "Main app bundle will be moved to Trash (Clean Uninstall mode)."
                : "Main app bundle will be moved to Trash."
        )
        let remnantItems = remnants.map(previewItem).sorted { $0.sizeInBytes > $1.sizeInBytes }
        return [appItem] + remnantItems
    }

    func buildVerifyReport(
        app: InstalledApp,
        previewItems: [UninstallPreviewItem],
        validation: UninstallValidationReport?,
        remaining: [AppRemnant],
        startupReferences: [UninstallStartupReference] = [],
        isProtectedPath: (String) -> Bool,
        isAppRunning: Bool
    ) -> UninstallVerifyReport {
        let attemptedPaths = Set(previewItems.map { $0.url.path })
        let actionByPath = Dictionary(uniqueKeysWithValues: (validation?.results ?? []).map { ($0.url.path, $0) })

        let issues = remaining.map { remnant in
            let path = remnant.url.path
            let risk = previewItem(for: remnant).risk
            let reason: String

            if let action = actionByPath[path] {
                switch action.status {
                case .skippedProtected:
                    reason = "Skipped: system-protected path (SIP/TCC)."
                case .failed:
                    reason = failedRemovalReason(for: action, path: path)
                case .missing:
                    reason = "Path changed during uninstall and was not removed."
                case .removed:
                    reason = isAppRunning
                    ? "Recreated after removal by a running process/helper."
                    : "Still present after remove call (possibly recreated by system helper)."
                }
            } else if isProtectedPath(path) {
                reason = "System-protected path (SIP/TCC)."
            } else if !attemptedPaths.contains(path) {
                reason = "Not selected for removal in uninstall scope."
            } else if !FileManager.default.isDeletableFile(atPath: path) {
                reason = "No delete permission for this item."
            } else if isAppRunning {
                reason = "Application is still running and may recreate this file."
            } else {
                reason = "Unknown: item remained after verification pass."
            }

            return UninstallVerifyIssue(
                url: remnant.url,
                sizeInBytes: remnant.sizeInBytes,
                reason: reason,
                risk: risk
            )
        }

        return UninstallVerifyReport(
            appName: app.name,
            createdAt: Date(),
            attemptedItems: attemptedPaths.count,
            removedItems: validation?.removedCount ?? 0,
            remaining: issues.sorted { $0.sizeInBytes > $1.sizeInBytes },
            startupReferences: startupReferences
        )
    }

    private func failedRemovalReason(for action: UninstallActionResult, path: String) -> String {
        let details = action.details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailText = details?.isEmpty == false ? details! : "unknown filesystem error"
        let remediation = action.remediationHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fix = remediation?.isEmpty == false ? " Fix: \(remediation!)." : ""

        switch action.failureCategory {
        case .launchDaemon:
            return "LaunchDaemon failed to remove: \(detailText). Next: reveal the plist, unload it with launchctl if it is active, then retry cleanup with administrator authorization.\(fix)"
        case .privilegedHelper:
            return "Privileged helper failed to remove: \(detailText). Next: reveal the helper and its LaunchDaemon plist, unload the daemon, then retry cleanup with administrator authorization.\(fix)"
        case .permissionDenied:
            return "Permission denied while removing: \(detailText). Next: grant Full Disk Access, verify ownership/ACL, then retry cleanup.\(fix)"
        case .protectedBySystem:
            return "System-protected path failed to remove: \(detailText). Next: keep it excluded unless you intentionally handle it outside DRay.\(fix)"
        case .runningProcessLock:
            return "Running helper/process kept this item: \(detailText). Next: quit the app and helpers, then retry cleanup.\(fix)"
        case .appStoreManaged, .itemLocked, .readOnlyVolume, .unknown, nil:
            if let remediation, !remediation.isEmpty {
                return "Failed to remove: \(detailText). Fix: \(remediation)"
            }
            if isDaemonPath(path) {
                return "LaunchDaemon/helper failed to remove: \(detailText). Next: reveal the item, unload related launchd job if active, then retry with administrator authorization."
            }
            return "Failed to remove: \(detailText)"
        }
    }

    private func isDaemonPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.contains("/library/launchdaemons/")
            || lower.contains("/library/privilegedhelpertools/")
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
