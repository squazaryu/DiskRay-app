import Foundation

struct UninstallObservedAppsUseCase {
    private let historyStore: OperationalHistoryStore
    private let observedFileName = "uninstall-observed-apps.json"
    private let observedLegacyDefaultsKey = "dray.uninstall.observed.apps"
    private let removedCandidatesFileName = "uninstall-removed-candidates.json"
    private let removedCandidatesLegacyDefaultsKey = "dray.uninstall.removed.candidates"
    private let maxCandidates: Int

    init(
        historyStore: OperationalHistoryStore,
        maxCandidates: Int = 300
    ) {
        self.historyStore = historyStore
        self.maxCandidates = max(1, maxCandidates)
    }

    func loadRemovedCandidates() -> [UninstallRemovedAppCandidate] {
        historyStore.load(
            [UninstallRemovedAppCandidate].self,
            fileName: removedCandidatesFileName,
            legacyDefaultsKey: removedCandidatesLegacyDefaultsKey
        ) ?? []
    }

    @discardableResult
    func updateObservedApps(currentApps: [InstalledApp], now: Date = Date()) -> [UninstallRemovedAppCandidate] {
        let previousObserved = historyStore.load(
            [UninstallObservedApp].self,
            fileName: observedFileName,
            legacyDefaultsKey: observedLegacyDefaultsKey
        ) ?? []

        let currentObserved = currentApps.map {
            UninstallObservedApp(
                appName: $0.name,
                bundleID: normalizedBundleID($0.bundleID),
                appPath: normalizedPath($0.appURL.path),
                observedAt: now
            )
        }
        historyStore.save(currentObserved, fileName: observedFileName)

        var existingCandidates = loadRemovedCandidates()
        let currentBundleIDs = Set(currentObserved.map(\.bundleID))
        let currentPaths = Set(currentObserved.map(\.appPath))

        // Remove candidates that are present again.
        existingCandidates.removeAll { candidate in
            let hasBundleID = candidate.bundleID.flatMap { normalizedBundleID($0) }
            let hasPath = candidate.lastKnownAppPath.map(normalizedPath)
            if let hasBundleID, currentBundleIDs.contains(hasBundleID) {
                return true
            }
            if let hasPath, currentPaths.contains(hasPath) {
                return true
            }
            return false
        }

        let missing = previousObserved.filter { observed in
            !currentBundleIDs.contains(observed.bundleID) && !currentPaths.contains(observed.appPath)
        }

        for observed in missing {
            let candidate = UninstallRemovedAppCandidate(
                appName: observed.appName,
                bundleID: observed.bundleID,
                lastKnownAppPath: observed.appPath,
                detectedAt: now
            )
            if !containsCandidate(existingCandidates, candidate: candidate) {
                existingCandidates.insert(candidate, at: 0)
            }
        }

        if existingCandidates.count > maxCandidates {
            existingCandidates = Array(existingCandidates.prefix(maxCandidates))
        }
        historyStore.save(existingCandidates, fileName: removedCandidatesFileName)
        return existingCandidates
    }

    private func containsCandidate(
        _ list: [UninstallRemovedAppCandidate],
        candidate: UninstallRemovedAppCandidate
    ) -> Bool {
        let bundle = candidate.bundleID.flatMap(normalizedBundleID)
        let path = candidate.lastKnownAppPath.map(normalizedPath)
        let name = candidate.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return list.contains { existing in
            if let bundle,
               let existingBundle = existing.bundleID.flatMap(normalizedBundleID),
               existingBundle == bundle {
                return true
            }
            if let path,
               let existingPath = existing.lastKnownAppPath.map(normalizedPath),
               existingPath == path {
                return true
            }
            return existing.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name
        }
    }

    private func normalizedBundleID(_ bundleID: String) -> String {
        bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
