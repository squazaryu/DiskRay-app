import Foundation

actor PrivacyService {
    private let protectedPathPrefixes = ["/System", "/bin", "/sbin", "/usr"]

    func runScan() -> PrivacyScanReport {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let categorySpecs: [(String, String, String, PrivacyRisk, [URL])] = [
            (
                "browser-cache",
                "Browser Caches",
                "Cached website data from Safari/Chrome/Firefox.",
                .low,
                [
                    home.appendingPathComponent("Library/Caches/com.apple.Safari"),
                    home.appendingPathComponent("Library/Caches/Google/Chrome"),
                    home.appendingPathComponent("Library/Caches/Firefox")
                ]
            ),
            (
                "browser-history",
                "Browser Histories",
                "History and session databases from major browsers.",
                .high,
                [
                    home.appendingPathComponent("Library/Safari/History.db"),
                    home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/History"),
                    home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
                ]
            ),
            (
                "messenger-cache",
                "Messenger Caches",
                "Local caches and logs from chat apps.",
                .medium,
                [
                    home.appendingPathComponent("Library/Caches/com.tdesktop.Telegram"),
                    home.appendingPathComponent("Library/Application Support/Telegram Desktop"),
                    home.appendingPathComponent("Library/Application Support/Discord"),
                    home.appendingPathComponent("Library/Caches/com.hnc.Discord")
                ]
            ),
            (
                "recent-docs",
                "Recent Files Metadata",
                "macOS metadata that stores recently opened documents.",
                .medium,
                [
                    home.appendingPathComponent("Library/Application Support/com.apple.sharedfilelist"),
                    home.appendingPathComponent("Library/Preferences/com.apple.recentitems.plist")
                ]
            ),
            (
                "quicklook",
                "QuickLook Thumbnails",
                "Generated previews and thumbnails for opened files.",
                .low,
                [
                    home.appendingPathComponent("Library/Caches/com.apple.QuickLook.thumbnailcache")
                ]
            )
        ]

        var categories: [PrivacyCategory] = []
        for (id, title, details, risk, roots) in categorySpecs {
            let artifacts = collectArtifacts(at: roots)
            guard !artifacts.isEmpty else { continue }
            categories.append(PrivacyCategory(
                id: id,
                title: title,
                details: details,
                risk: risk,
                artifacts: artifacts.sorted { $0.sizeInBytes > $1.sizeInBytes }
            ))
        }

        return PrivacyScanReport(generatedAt: Date(), categories: categories)
    }

    func clean(artifacts: [PrivacyArtifact]) -> PrivacyCleanReport {
        var moved = 0
        var failed = 0
        var skippedProtected = 0
        var cleanedBytes: Int64 = 0

        for artifact in artifacts {
            if isProtectedPath(artifact.url.path) {
                skippedProtected += 1
                continue
            }

            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: artifact.url, resultingItemURL: &trashedURL)
                moved += 1
                cleanedBytes += artifact.sizeInBytes
            } catch {
                failed += 1
            }
        }

        return PrivacyCleanReport(
            moved: moved,
            failed: failed,
            skippedProtected: skippedProtected,
            cleanedBytes: cleanedBytes
        )
    }

    private func collectArtifacts(at roots: [URL]) -> [PrivacyArtifact] {
        var result: [PrivacyArtifact] = []
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            result.append(PrivacyArtifact(url: root, sizeInBytes: size(at: root)))
        }
        return result
    }

    private func size(at url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
           values.isDirectory != true {
            return Int64(values.fileSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  values.isDirectory != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func isProtectedPath(_ path: String) -> Bool {
        path == "/" || protectedPathPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}
