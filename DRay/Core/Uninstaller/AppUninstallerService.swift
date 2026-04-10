import Foundation
import AppKit

actor AppUninstallerService: UninstallerServicing {
    func installedApps() -> [InstalledApp] {
        let appsURL = URL(fileURLWithPath: "/Applications")
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: appsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [InstalledApp] = []
        for appURL in urls where appURL.pathExtension == "app" {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier else { continue }
            result.append(InstalledApp(
                name: appURL.deletingPathExtension().lastPathComponent,
                bundleID: bundleID,
                appURL: appURL
            ))
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func findRemnants(for app: InstalledApp) -> [AppRemnant] {
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
        let tokens = searchTokens(for: app)
        var unique = Set<String>()
        var remnants: [AppRemnant] = []

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            let urls = matchedURLs(in: root, tokens: tokens, maxDepth: 3)
            for url in urls {
                guard unique.insert(url.path).inserted else { continue }
                let size = directorySize(at: url)
                remnants.append(AppRemnant(url: url, sizeInBytes: size))
            }
        }

        // Explicit coverage for login items (best-effort, sandbox/permissions can still limit access).
        let loginItemsPlist = home.appendingPathComponent("Library/Preferences/com.apple.loginitems.plist")
        if FileManager.default.fileExists(atPath: loginItemsPlist.path),
           unique.insert(loginItemsPlist.path).inserted {
            remnants.append(AppRemnant(url: loginItemsPlist, sizeInBytes: directorySize(at: loginItemsPlist)))
        }

        return remnants.sorted { $0.sizeInBytes > $1.sizeInBytes }
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

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) async -> UninstallValidationReport {
        var results: [UninstallActionResult] = []
        let targets: [(URL, UninstallItemType)] = previewItems.map { ($0.url, $0.type) }
        terminateIfRunning(bundleID: app.bundleID)

        for (target, type) in targets {
            let path = target.path

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
        let sanitizedName = app.name.lowercased().replacingOccurrences(of: " ", with: "")
        return [app.bundleID.lowercased(), app.name.lowercased(), sanitizedName]
            .filter { !$0.isEmpty }
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
            let target = url.lastPathComponent.lowercased()
            let path = url.path.lowercased()
            if tokens.contains(where: { target.contains($0) || path.contains($0) }) {
                result.append(url)
            }
        }
        return result
    }

    private func depth(of relativePath: String) -> Int {
        relativePath.split(separator: "/").filter { !$0.isEmpty }.count
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
            do shell script "/bin/mkdir -p \"$(/usr/bin/dirname " & quoted form of destinationPath & ")\"; /bin/mv -f " & quoted form of targetPath & " " & quoted form of destinationPath with administrator privileges
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
        if SystemPathProtection.isProtected(target.path) {
            return (
                .protectedBySystem,
                "Path is protected by SIP/TCC. Exclude it from uninstall or remove manually from recovery environment."
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
