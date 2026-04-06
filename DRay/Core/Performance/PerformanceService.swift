import Foundation

actor PerformanceService: PerformanceServicing {
    func buildReport() -> PerformanceReport {
        let startupEntries = discoverStartupEntries()
        let capacities = diskCapacity()
        let recommendations = makeRecommendations(
            startupEntries: startupEntries,
            freeBytes: capacities.free,
            totalBytes: capacities.total
        )
        return PerformanceReport(
            generatedAt: Date(),
            startupEntries: startupEntries,
            diskFreeBytes: capacities.free,
            diskTotalBytes: capacities.total,
            recommendations: recommendations
        )
    }

    private func discoverStartupEntries() -> [StartupEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots: [(URL, String)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), "User LaunchAgents"),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), "System LaunchAgents"),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), "System LaunchDaemons"),
            (URL(fileURLWithPath: "/Library/StartupItems"), "StartupItems")
        ]

        var result: [StartupEntry] = []
        for (root, source) in roots {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files {
                result.append(StartupEntry(
                    name: file.lastPathComponent,
                    url: file,
                    source: source,
                    sizeInBytes: fileSize(at: file)
                ))
            }
        }

        return result.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func fileSize(at url: URL) -> Int64 {
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

    private func diskCapacity() -> (free: Int64?, total: Int64?) {
        let root = URL(fileURLWithPath: "/")
        let values = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let free = values?.volumeAvailableCapacityForImportantUsage.map { Int64($0) }
        let total = values?.volumeTotalCapacity.map { Int64($0) }
        return (free, total)
    }

    private func makeRecommendations(startupEntries: [StartupEntry], freeBytes: Int64?, totalBytes: Int64?) -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []

        if startupEntries.count > 20 {
            recommendations.append(PerformanceRecommendation(
                title: "Too many startup items",
                details: "Detected \(startupEntries.count) startup entries. Review non-essential launch agents/daemons.",
                action: .selectAllStartup
            ))
        }

        if let freeBytes, let totalBytes, totalBytes > 0 {
            let ratio = Double(freeBytes) / Double(totalBytes)
            if ratio < 0.12 {
                recommendations.append(PerformanceRecommendation(
                    title: "Low free disk space",
                    details: "Free space is below 12%. Run Smart Care and remove large startup-related leftovers.",
                    action: .openSmartCare
                ))
            }
        }

        let heavyEntries = startupEntries.filter { $0.sizeInBytes > 100 * 1_048_576 }
        if !heavyEntries.isEmpty {
            recommendations.append(PerformanceRecommendation(
                title: "Heavy startup components",
                details: "\(heavyEntries.count) startup components exceed 100 MB. Check if they are still needed.",
                action: .selectHeavyStartup
            ))
        }

        if recommendations.isEmpty {
            recommendations.append(PerformanceRecommendation(
                title: "Startup state looks healthy",
                details: "No critical startup issues were detected in current baseline checks.",
                action: .runDiagnostics
            ))
        }

        return recommendations
    }

    func cleanupStartupEntries(_ entries: [StartupEntry]) -> StartupCleanupReport {
        var moved = 0
        var failed = 0
        var skippedProtected = 0

        for entry in entries {
            let path = entry.url.path
            if SystemPathProtection.isProtected(path) {
                skippedProtected += 1
                continue
            }
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: entry.url, resultingItemURL: &trashedURL)
                moved += 1
            } catch {
                failed += 1
            }
        }

        return StartupCleanupReport(moved: moved, failed: failed, skippedProtected: skippedProtected)
    }
}
