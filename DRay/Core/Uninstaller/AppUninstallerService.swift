import Foundation
import AppKit

actor AppUninstallerService: UninstallerServicing {
    private static let deepSweepBundlePattern = try! NSRegularExpression(
        pattern: #"[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*){2,}"#
    )

    func installedApps() -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var result: [InstalledApp] = []
        var uniquePaths = Set<String>()

        let currentAppBundlePath = Bundle.main.bundleURL.standardizedFileURL.path

        for root in roots {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for appURL in urls where appURL.pathExtension == "app" {
                if appURL.standardizedFileURL.path == currentAppBundlePath {
                    continue
                }
                guard uniquePaths.insert(appURL.path).inserted else { continue }
                let bundle = Bundle(url: appURL)
                let bundleID = bundle?.bundleIdentifier ?? fallbackBundleIdentifier(for: appURL)
                result.append(InstalledApp(
                    name: appURL.deletingPathExtension().lastPathComponent,
                    bundleID: bundleID,
                    appURL: appURL
                ))
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func findRemnants(for app: InstalledApp, mode: UninstallMode) -> [AppRemnant] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let userRoots = [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Group Containers"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/LaunchAgents")
        ]
        let systemRoots = [
            URL(fileURLWithPath: "/Library/Application Support"),
            URL(fileURLWithPath: "/Library/Caches"),
            URL(fileURLWithPath: "/Library/Preferences"),
            URL(fileURLWithPath: "/Library/Logs"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
            URL(fileURLWithPath: "/Library/PrivilegedHelperTools"),
            URL(fileURLWithPath: "/Library/StartupItems")
        ]

        let roots = userRoots + systemRoots
        let strictBundleID = strictBundleID(for: app.bundleID)
        var unique = Set<String>()
        var remnants: [AppRemnant] = []
        let maxDepth = mode == .clean ? 5 : 3

        // Scheduled/app-bound scan should only work on strong app identity.
        // Avoid fuzzy name-based matching to prevent false positives.
        if let strictBundleID {
            for root in roots where FileManager.default.fileExists(atPath: root.path) {
                let urls = matchedURLs(in: root, tokens: [strictBundleID], maxDepth: maxDepth)
                for url in urls {
                    guard unique.insert(url.path).inserted else { continue }
                    let size = directorySize(at: url)
                    remnants.append(AppRemnant(url: url, sizeInBytes: size))
                }
            }
        }

        if mode == .clean || strictBundleID != nil {
            for explicit in explicitRemnantURLs(for: app) {
                let normalized = explicit.standardizedFileURL.path
                guard FileManager.default.fileExists(atPath: normalized) else { continue }
                guard unique.insert(normalized).inserted else { continue }
                let url = URL(fileURLWithPath: normalized)
                remnants.append(AppRemnant(url: url, sizeInBytes: directorySize(at: url)))
            }
        }

        // Explicit coverage for login items (best-effort, sandbox/permissions can still limit access).
        let loginItemsPlist = home.appendingPathComponent("Library/Preferences/com.apple.loginitems.plist")
        if let strictBundleID,
           fileContainsAnyToken(loginItemsPlist, tokens: [strictBundleID]),
           unique.insert(loginItemsPlist.path).inserted {
            remnants.append(AppRemnant(url: loginItemsPlist, sizeInBytes: directorySize(at: loginItemsPlist)))
        }

        return remnants
            .filter { isAppBoundPath($0.url.path, bundleID: strictBundleID) }
            .sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    func findStartupReferences(for app: InstalledApp) -> [UninstallStartupReference] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tokens = searchTokens(for: app)
        var references: [UninstallStartupReference] = []
        var seen = Set<String>()

        let startupRoots: [(url: URL, source: UninstallStartupReferenceSource, reason: String)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .userLaunchAgent, "LaunchAgent can restart app after user login."),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemLaunchAgent, "System LaunchAgent may restart app at login."),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemLaunchDaemon, "LaunchDaemon may restart app in background."),
            (URL(fileURLWithPath: "/Library/StartupItems"), .startupItems, "Startup item can trigger relaunch during boot.")
        ]

        for root in startupRoots where FileManager.default.fileExists(atPath: root.url.path) {
            let urls = matchedURLs(in: root.url, tokens: tokens, maxDepth: 3)
            for url in urls where seen.insert(url.path).inserted {
                references.append(
                    UninstallStartupReference(
                        source: root.source,
                        url: url,
                        details: url.path,
                        reason: root.reason
                    )
                )
            }
        }

        let loginItemsPlist = home.appendingPathComponent("Library/Preferences/com.apple.loginitems.plist")
        if fileContainsAnyToken(loginItemsPlist, tokens: tokens), seen.insert(loginItemsPlist.path).inserted {
            references.append(
                UninstallStartupReference(
                    source: .loginItems,
                    url: loginItemsPlist,
                    details: "com.apple.loginitems.plist contains app token",
                    reason: "Legacy Login Items list may relaunch the app."
                )
            )
        }

        let backgroundItems = home.appendingPathComponent("Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm")
        if fileContainsAnyToken(backgroundItems, tokens: tokens), seen.insert(backgroundItems.path).inserted {
            references.append(
                UninstallStartupReference(
                    source: .backgroundItems,
                    url: backgroundItems,
                    details: "backgrounditems.btm contains app token",
                    reason: "Background Task Management entry may relaunch app/helper."
                )
            )
        }

        return references.sorted { lhs, rhs in
            let leftPath = lhs.displayPath
            let rightPath = rhs.displayPath
            return leftPath.localizedCaseInsensitiveCompare(rightPath) == .orderedAscending
        }
    }

    func deepSweepOrphanRemnants(installedApps: [InstalledApp]) -> [UninstallDeepSweepCandidate] {
        let installedBundleIDs = Set(installedApps.map { normalizedBundleID($0.bundleID) })
        let roots = deepSweepRoots()
        let maxDepth = 4
        let maxMatches = 2_500
        let maxIssuesPerBundle = 60

        var grouped: [String: [UninstallVerifyIssue]] = [:]
        var seenPaths = Set<String>()
        var totalMatches = 0

        outerLoop: for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                let relative = url.path.replacingOccurrences(of: root.path, with: "")
                if depth(of: relative) > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }

                let normalizedPath = URL(fileURLWithPath: url.path).standardizedFileURL.path
                guard seenPaths.insert(normalizedPath).inserted else { continue }

                let bundleIDCandidates = extractBundleIDs(from: normalizedPath)
                guard
                    let bundleID = bundleIDCandidates.first(where: { candidate in
                        shouldIncludeDeepSweepBundleID(candidate, installedBundleIDs: installedBundleIDs)
                    })
                else { continue }

                let issue = UninstallVerifyIssue(
                    url: url,
                    sizeInBytes: directorySize(at: url),
                    reason: "Detected by deep sweep as an orphaned artifact for a missing app bundle.",
                    risk: deepSweepRisk(for: normalizedPath)
                )
                grouped[bundleID, default: []].append(issue)
                totalMatches += 1
                if totalMatches >= maxMatches {
                    break outerLoop
                }
            }
        }

        return grouped.map { bundleID, issues in
            UninstallDeepSweepCandidate(
                appName: appNameFromBundleID(bundleID),
                bundleID: bundleID,
                issues: Array(
                    issues.sorted { lhs, rhs in
                        if lhs.sizeInBytes != rhs.sizeInBytes {
                            return lhs.sizeInBytes > rhs.sizeInBytes
                        }
                        return lhs.url.path.localizedCaseInsensitiveCompare(rhs.url.path) == .orderedAscending
                    }
                    .prefix(maxIssuesPerBundle)
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalSizeInBytes != rhs.totalSizeInBytes {
                return lhs.totalSizeInBytes > rhs.totalSizeInBytes
            }
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        var results: [UninstallActionResult] = []
        let targets: [(URL, UninstallItemType)] = previewItems.map { ($0.url, $0.type) }
        terminateIfRunning(bundleID: app.bundleID)
        let currentAppBundlePath = Bundle.main.bundleURL.standardizedFileURL.path

        for (target, type) in targets {
            let path = target.path

            if target.standardizedFileURL.path == currentAppBundlePath {
                results.append(
                    UninstallActionResult(
                        url: target,
                        type: type,
                        status: .failed,
                        trashedPath: nil,
                        details: "Self-uninstall is blocked for safety.",
                        failureCategory: .protectedBySystem,
                        remediationHint: "DRay cannot remove itself from the Uninstaller module."
                    )
                )
                continue
            }

            if SystemPathProtection.isProtected(path) {
                results.append(
                    UninstallActionResult(
                        url: target,
                        type: type,
                        status: .skippedProtected,
                        trashedPath: nil,
                        details: "Protected system path",
                        failureCategory: .protectedBySystem,
                        remediationHint: "System files protected by SIP/TCC cannot be removed."
                    )
                )
                continue
            }

            guard FileManager.default.fileExists(atPath: path) else {
                results.append(UninstallActionResult(url: target, type: type, status: .missing, trashedPath: nil, details: "Not found"))
                continue
            }

            var primaryTrashError: Error?
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: target, resultingItemURL: &trashedURL)
                results.append(UninstallActionResult(
                    url: target,
                    type: type,
                    status: .removed,
                    trashedPath: (trashedURL as URL?)?.path,
                    details: nil
                ))
                continue
            } catch {
                primaryTrashError = error
            }

            // Finder-based recycle handles some App Store installed apps better than FileManager.trashItem.
            let recycleResult = await recycleWithFinder(target: target)
            if recycleResult.success {
                results.append(UninstallActionResult(
                    url: target,
                    type: type,
                    status: .removed,
                    trashedPath: recycleResult.trashedPath,
                    details: recycleResult.details
                ))
                continue
            }

            let primaryErrorMessage = primaryTrashError?.localizedDescription ?? "Unknown filesystem error"
            var attempts: [String] = ["FileManager.trashItem: \(primaryErrorMessage)"]
            if let recycleDetails = recycleResult.details, !recycleDetails.isEmpty {
                attempts.append("Finder recycle: \(recycleDetails)")
            } else {
                attempts.append("Finder recycle failed")
            }

            if type == .appBundle, path.hasPrefix("/Applications/"), isPermissionError(primaryTrashError ?? NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)) {
                let adminTrashResult = moveToTrashWithAdministratorPrivileges(target: target)
                if adminTrashResult.success {
                    results.append(UninstallActionResult(
                        url: target,
                        type: type,
                        status: .removed,
                        trashedPath: adminTrashResult.trashedPath,
                        details: adminTrashResult.details
                    ))
                    continue
                }
                attempts.append("Admin move to trash: \(adminTrashResult.details)")

                // Last-resort path for App Store bundles when trash APIs are denied by App Management/TCC.
                let adminRemoveResult = removeWithAdministratorPrivileges(target: target)
                if adminRemoveResult.success {
                    results.append(UninstallActionResult(
                        url: target,
                        type: type,
                        status: .removed,
                        trashedPath: nil,
                        details: adminRemoveResult.details
                    ))
                    continue
                }
                attempts.append("Admin hard remove: \(adminRemoveResult.details)")
            }

            let diagnosis = diagnoseDeleteFailure(
                target: target,
                type: type,
                initialError: primaryTrashError,
                appBundleID: app.bundleID
            )
            results.append(
                UninstallActionResult(
                    url: target,
                    type: type,
                    status: .failed,
                    trashedPath: nil,
                    details: attempts.joined(separator: " | "),
                    failureCategory: diagnosis.category,
                    remediationHint: diagnosis.remediation
                )
            )
        }

        return UninstallValidationReport(appName: app.name, createdAt: Date(), results: results)
    }

    private func searchTokens(for app: InstalledApp) -> [String] {
        let normalizedBundleID = app.bundleID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedName = app.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let sanitizedName = normalizedName
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        var tokens: [String] = []
        if !normalizedBundleID.isEmpty,
           !normalizedBundleID.hasPrefix("unknown."),
           !normalizedBundleID.hasPrefix("local.") {
            tokens.append(normalizedBundleID)
        }
        if normalizedName.count >= 4 {
            tokens.append(normalizedName)
        }
        if sanitizedName.count >= 4, sanitizedName != normalizedName {
            tokens.append(sanitizedName)
        }
        return Array(Set(tokens))
    }

    private func strictBundleID(for bundleID: String) -> String? {
        let normalized = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        guard !normalized.hasPrefix("unknown."), !normalized.hasPrefix("local.") else { return nil }
        guard normalized.contains(".") else { return nil }
        return normalized
    }

    private func deepSweepRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Group Containers"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/Application Support"),
            URL(fileURLWithPath: "/Library/Caches"),
            URL(fileURLWithPath: "/Library/Preferences"),
            URL(fileURLWithPath: "/Library/Logs"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
            URL(fileURLWithPath: "/Library/PrivilegedHelperTools")
        ]
    }

    private func extractBundleIDs(from path: String) -> [String] {
        let lowercased = path.lowercased()
        let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
        let matches = Self.deepSweepBundlePattern.matches(in: lowercased, options: [], range: range)
        var seen = Set<String>()
        var result: [String] = []

        for match in matches {
            guard let swiftRange = Range(match.range, in: lowercased) else { continue }
            var bundleID = String(lowercased[swiftRange])
            if bundleID.hasPrefix("group.") {
                bundleID.removeFirst("group.".count)
            }
            guard seen.insert(bundleID).inserted else { continue }
            result.append(bundleID)
        }

        return result
    }

    private func shouldIncludeDeepSweepBundleID(
        _ bundleID: String,
        installedBundleIDs: Set<String>
    ) -> Bool {
        if installedBundleIDs.contains(bundleID) {
            return false
        }
        if bundleID.hasPrefix("com.apple.") {
            return false
        }
        if bundleID.hasPrefix("apple.") {
            return false
        }
        if bundleID.hasPrefix("group.com.apple.") {
            return false
        }
        return true
    }

    private func appNameFromBundleID(_ bundleID: String) -> String {
        let tail = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        let normalized = tail
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return bundleID }
        return normalized
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return String(word) }
                return String(first).uppercased() + String(word.dropFirst())
            }
            .joined(separator: " ")
    }

    private func deepSweepRisk(for path: String) -> UninstallRiskLevel {
        let lower = path.lowercased()
        if lower.contains("/launchagents/") || lower.contains("/launchdaemons/") || lower.contains("/startupitems/") {
            return .high
        }
        if lower.contains("/containers/") || lower.contains("/group containers/") || lower.contains("/application support/") {
            return .medium
        }
        return .low
    }

    private func normalizedBundleID(_ bundleID: String) -> String {
        bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func fileContainsAnyToken(_ url: URL, tokens: [String]) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let data = try? Data(contentsOf: url) else { return false }
        guard !data.isEmpty else { return false }

        let text = String(decoding: data, as: UTF8.self).lowercased()
        if tokens.contains(where: { text.contains($0) }) {
            return true
        }

        return tokens.contains { token in
            guard let tokenData = token.data(using: .utf8), !tokenData.isEmpty else { return false }
            return data.range(of: tokenData) != nil
        }
    }

    private func matchedURLs(in root: URL, tokens: [String], maxDepth: Int) -> [URL] {
        guard !tokens.isEmpty else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator {
            let relativePath = url.path.replacingOccurrences(of: root.path, with: "").lowercased()
            if depth(of: relativePath) > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            if tokens.contains(where: { tokenMatchesPath($0, url: url) }) {
                result.append(url)
            }
        }
        return result
    }

    private func tokenMatchesPath(_ token: String, url: URL) -> Bool {
        let path = url.path.lowercased()
        let leaf = url.lastPathComponent.lowercased()

        if token.contains(".") {
            if path.contains("/\(token)") || path.contains(".\(token)") || path.contains("\(token).") {
                return true
            }
            return false
        }

        guard token.count >= 4 else { return false }
        if leaf == token {
            return true
        }
        let boundaryTokens = ["/\(token)/", "/\(token).", ".\(token).", "-\(token)-", "_\(token)_", ".\(token)_", "_\(token)."]
        if boundaryTokens.contains(where: { path.contains($0) }) {
            return true
        }
        if path.hasSuffix("/\(token)") || path.hasSuffix(".\(token)") || path.hasSuffix("_\(token)") || path.hasSuffix("-\(token)") {
            return true
        }
        return false
    }

    private func isAppBoundPath(_ path: String, bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        let lower = path.lowercased()
        let exactPatterns = [
            "/\(bundleID)/",
            "/\(bundleID).",
            ".\(bundleID).",
            "/\(bundleID)-",
            "/\(bundleID)_"
        ]
        if exactPatterns.contains(where: { lower.contains($0) }) {
            return true
        }
        return lower.hasSuffix("/\(bundleID)")
            || lower.hasSuffix(".\(bundleID)")
            || lower.hasSuffix("/\(bundleID).plist")
    }

    private func depth(of relativePath: String) -> Int {
        relativePath.split(separator: "/").filter { !$0.isEmpty }.count
    }

    private func fallbackBundleIdentifier(for appURL: URL) -> String {
        let basename = appURL.deletingPathExtension().lastPathComponent
        let sanitized = basename
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if sanitized.isEmpty {
            return "local.unknown.\(UUID().uuidString.lowercased())"
        }
        return "local.\(sanitized)"
    }

    private func explicitRemnantURLs(for app: InstalledApp) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bundleID = app.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var urls: [URL] = []

        if !bundleID.isEmpty {
            urls.append(home.appendingPathComponent("Library/Containers/\(bundleID)"))
            urls.append(home.appendingPathComponent("Library/Group Containers/\(bundleID)"))
            urls.append(home.appendingPathComponent("Library/Application Scripts/\(bundleID)"))
            urls.append(home.appendingPathComponent("Library/WebKit/\(bundleID)"))
            urls.append(home.appendingPathComponent("Library/HTTPStorages/\(bundleID)"))
            urls.append(home.appendingPathComponent("Library/HTTPStorages/\(bundleID).binarycookies"))
            urls.append(home.appendingPathComponent("Library/Preferences/\(bundleID).plist"))
            urls.append(URL(fileURLWithPath: "/Library/Preferences/\(bundleID).plist"))
            urls.append(URL(fileURLWithPath: "/Library/LaunchAgents/\(bundleID).plist"))
            urls.append(URL(fileURLWithPath: "/Library/LaunchDaemons/\(bundleID).plist"))
            urls.append(URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(bundleID)"))
        }

        if !appName.isEmpty {
            urls.append(home.appendingPathComponent("Library/Saved Application State/\(appName).savedState"))
            urls.append(URL(fileURLWithPath: "/Library/StartupItems/\(appName)"))
        }

        return urls
    }

    private func directorySize(at url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
           values.isDirectory != true {
            return Int64(values.fileSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  values.isDirectory != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func terminateIfRunning(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }

        running.forEach { _ = $0.terminate() }

        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .forEach { _ = $0.forceTerminate() }
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            let codes: Set<Int> = [
                NSFileReadNoPermissionError,
                NSFileWriteNoPermissionError,
                NSFileWriteVolumeReadOnlyError,
                NSFileWriteFileExistsError
            ]
            if codes.contains(nsError.code) {
                return true
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == EACCES || nsError.code == EPERM
        }

        let message = nsError.localizedDescription.lowercased()
        return message.contains("permission") || message.contains("not permitted") || message.contains("operation not permitted")
    }

    private func recycleWithFinder(target: URL) async -> (success: Bool, trashedPath: String?, details: String?) {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                NSWorkspace.shared.recycle([target]) { recycledMap, error in
                    if let recycled = recycledMap[target] ?? recycledMap.values.first {
                        continuation.resume(returning: (true, recycled.path, "Moved to Trash via Finder recycle."))
                        return
                    }
                    if !FileManager.default.fileExists(atPath: target.path) {
                        continuation.resume(returning: (true, nil, "Item removed by Finder recycle fallback."))
                        return
                    }
                    continuation.resume(returning: (false, nil, error?.localizedDescription ?? "Unknown Finder recycle error"))
                }
            }
        }
    }

    private func moveToTrashWithAdministratorPrivileges(target: URL) -> (success: Bool, trashedPath: String?, details: String) {
        let trashRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        let destination = "\(trashRoot)/\(UUID().uuidString)-\(target.lastPathComponent)"
        let script = """
        on run argv
            set targetPath to item 1 of argv
            set destinationPath to item 2 of argv
            set parentPath to do shell script "/usr/bin/dirname " & quoted form of destinationPath
            do shell script "/bin/mkdir -p " & quoted form of parentPath with administrator privileges
            do shell script "/bin/mv -f " & quoted form of targetPath & " " & quoted form of destinationPath with administrator privileges
            return "ok"
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, target.path, destination]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (
                    true,
                    destination,
                    "Moved to Trash with administrator authorization."
                )
            }

            let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (false, nil, output?.isEmpty == false ? output! : "osascript returned \(process.terminationStatus)")
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    private func removeWithAdministratorPrivileges(target: URL) -> (success: Bool, details: String) {
        let script = """
        on run argv
            set targetPath to item 1 of argv
            do shell script "/bin/rm -rf " & quoted form of targetPath with administrator privileges
            return "ok"
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, target.path]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (true, "Removed with administrator authorization.")
            }
            let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (false, output?.isEmpty == false ? output! : "osascript returned \(process.terminationStatus)")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func diagnoseDeleteFailure(
        target: URL,
        type: UninstallItemType,
        initialError: Error?,
        appBundleID: String
    ) -> (category: UninstallFailureCategory, remediation: String) {
        let lowerPath = target.path.lowercased()

        if SystemPathProtection.isProtected(target.path) {
            return (
                .protectedBySystem,
                "Path is protected by SIP/TCC. Exclude it from uninstall or remove manually from recovery environment."
            )
        }

        if lowerPath.contains("/library/launchdaemons/") {
            return (
                .launchDaemon,
                "LaunchDaemon requires admin removal and may be loaded by launchd. Reveal it, unload with launchctl if needed, then retry cleanup with administrator authorization."
            )
        }

        if lowerPath.contains("/library/privilegedhelpertools/") {
            return (
                .privilegedHelper,
                "Privileged helper requires admin removal and may be referenced by a LaunchDaemon. Reveal both helper and daemon plist, unload the daemon, then retry cleanup."
            )
        }

        if isRunningAppBundle(path: target.path, bundleID: appBundleID) {
            return (
                .runningProcessLock,
                "Quit app and related helpers, then retry uninstall."
            )
        }

        if isImmutable(path: target.path) {
            return (
                .itemLocked,
                "Item is locked/immutable. Unlock in Finder (Get Info) or clear immutable flag, then retry."
            )
        }

        if isOnReadOnlyVolume(target) {
            return (
                .readOnlyVolume,
                "Item is on a read-only volume. Move it to writable storage or remount writable."
            )
        }

        if type == .appBundle, hasAppStoreReceipt(in: target) {
            return (
                .appStoreManaged,
                "App Store bundle may require administrator authorization/App Management access. Keep DRay in Full Disk Access and retry."
            )
        }

        if let initialError, isPermissionError(initialError) {
            return (
                .permissionDenied,
                "Access denied by permissions/ownership/ACL. Re-check Full Disk Access and target write permissions, then retry."
            )
        }

        return (
            .unknown,
            "Unknown removal failure. Reveal path and inspect ACL/owner/flags, then retry."
        )
    }

    private func hasAppStoreReceipt(in appURL: URL) -> Bool {
        let receipt = appURL.appendingPathComponent("Contents/_MASReceipt/receipt")
        return FileManager.default.fileExists(atPath: receipt.path)
    }

    private func isOnReadOnlyVolume(_ url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.volumeIsReadOnlyKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        return values.volumeIsReadOnly == true
    }

    private func isImmutable(path: String) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return false }
        let immutableValue = attrs[.immutable]
        if let boolValue = immutableValue as? Bool {
            return boolValue
        }
        if let number = immutableValue as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private func isRunningAppBundle(path: String, bundleID: String) -> Bool {
        guard path.hasSuffix(".app") else { return false }
        if !bundleID.isEmpty {
            return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        }
        return false
    }
}
