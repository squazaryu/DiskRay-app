import Foundation

actor AppUninstallerService {
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
        let candidateRoots = [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Group Containers")
        ]

        var remnants: [AppRemnant] = []
        for root in candidateRoots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for case let url as URL in enumerator {
                let path = url.path.lowercased()
                let key = app.bundleID.lowercased()
                let name = app.name.lowercased()
                if !path.contains(key) && !path.contains(name) { continue }

                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]), values.isDirectory != true else { continue }
                remnants.append(AppRemnant(url: url, sizeInBytes: Int64(values.fileSize ?? 0)))
            }
        }

        return remnants.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    func uninstall(app: InstalledApp, remnants: [AppRemnant]) -> (moved: Int, failed: Int) {
        var moved = 0
        var failed = 0

        let targets = [app.appURL] + remnants.map(\.url)
        for target in targets {
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: target, resultingItemURL: &trashedURL)
                moved += 1
            } catch {
                failed += 1
            }
        }

        return (moved, failed)
    }
}
