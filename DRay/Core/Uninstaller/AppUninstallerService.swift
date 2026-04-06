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

    func uninstall(app: InstalledApp, previewItems: [UninstallPreviewItem]) -> UninstallValidationReport {
        var results: [UninstallActionResult] = []
        let targets: [(URL, UninstallItemType)] = previewItems.map { ($0.url, $0.type) }
        terminateIfRunning(bundleID: app.bundleID)

        for (target, type) in targets {
            let path = target.path

            if SystemPathProtection.isProtected(path) {
                results.append(UninstallActionResult(url: target, type: type, status: .skippedProtected, trashedPath: nil, details: "Protected system path"))
                continue
            }

            guard FileManager.default.fileExists(atPath: path) else {
                results.append(UninstallActionResult(url: target, type: type, status: .missing, trashedPath: nil, details: "Not found"))
                continue
            }

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
            } catch {
                if type == .appBundle,
                   path.hasPrefix("/Applications/"),
                   isPermissionError(error),
                   moveToTrashWithAdministratorPrivileges(target: target) {
                    let userTrash = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".Trash/\(target.lastPathComponent)").path
                    results.append(UninstallActionResult(
                        url: target,
                        type: type,
                        status: .removed,
                        trashedPath: userTrash,
                        details: "Moved to Trash with administrator authorization."
                    ))
                    continue
                }
                results.append(UninstallActionResult(url: target, type: type, status: .failed, trashedPath: nil, details: error.localizedDescription))
            }
        }

        return UninstallValidationReport(appName: app.name, createdAt: Date(), results: results)
    }

    private func searchTokens(for app: InstalledApp) -> [String] {
        let sanitizedName = app.name.lowercased().replacingOccurrences(of: " ", with: "")
        return [app.bundleID.lowercased(), app.name.lowercased(), sanitizedName]
            .filter { !$0.isEmpty }
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

    private func moveToTrashWithAdministratorPrivileges(target: URL) -> Bool {
        let script = """
        on run argv
            set targetPath to item 1 of argv
            do shell script "/bin/mkdir -p \"$HOME/.Trash\"; /bin/mv " & quoted form of targetPath & " \"$HOME/.Trash/\"" with administrator privileges
            return "ok"
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, target.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
