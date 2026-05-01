import Foundation

struct UninstallRemainingUseCase {
    private let historyStore: OperationalHistoryStore
    private let fileManager: FileManager
    private let recordLimit: Int
    private let fileName = "uninstall-remaining.json"
    private let legacyDefaultsKey = "dray.uninstall.remaining"

    init(
        historyStore: OperationalHistoryStore,
        fileManager: FileManager = .default,
        recordLimit: Int = 120
    ) {
        self.historyStore = historyStore
        self.fileManager = fileManager
        self.recordLimit = max(1, recordLimit)
    }

    func load() -> [UninstallRemainingRecord] {
        historyStore.load(
            [UninstallRemainingRecord].self,
            fileName: fileName,
            legacyDefaultsKey: legacyDefaultsKey
        ) ?? []
    }

    func save(_ records: [UninstallRemainingRecord]) {
        historyStore.save(records, fileName: fileName)
    }

    func upsert(
        appName: String,
        bundleID: String?,
        issues: [UninstallVerifyIssue],
        updatedAt: Date,
        existing: [UninstallRemainingRecord]
    ) -> [UninstallRemainingRecord] {
        let records = mergedRecords(
            appName: appName,
            bundleID: bundleID,
            issues: issues,
            updatedAt: updatedAt,
            existing: existing
        )
        save(records)
        return records
    }

    func mergeDeepSweepCandidates(
        _ candidates: [UninstallDeepSweepCandidate],
        existing: [UninstallRemainingRecord],
        updatedAt: Date = Date()
    ) -> [UninstallRemainingRecord] {
        guard !candidates.isEmpty else { return pruneMissing(existing: existing) }

        var records = existing
        for candidate in candidates {
            records = mergedRecords(
                appName: candidate.appName,
                bundleID: candidate.bundleID,
                issues: candidate.issues,
                updatedAt: updatedAt,
                existing: records
            )
        }

        let pruned = records.compactMap { record -> UninstallRemainingRecord? in
            let issues = record.issues.filter { fileManager.fileExists(atPath: $0.path) }
            guard !issues.isEmpty else { return nil }
            return UninstallRemainingRecord(
                id: record.id,
                appName: record.appName,
                bundleID: record.bundleID,
                updatedAt: record.updatedAt,
                issues: issues
            )
        }
        save(pruned)
        return pruned
    }

    func pruneMissing(existing: [UninstallRemainingRecord]) -> [UninstallRemainingRecord] {
        let records = existing.compactMap { record -> UninstallRemainingRecord? in
            let issues = record.issues.filter { fileManager.fileExists(atPath: $0.path) }
            guard !issues.isEmpty else { return nil }
            return UninstallRemainingRecord(
                id: record.id,
                appName: record.appName,
                bundleID: record.bundleID,
                updatedAt: record.updatedAt,
                issues: issues
            )
        }
        save(records)
        return records
    }

    func removeRecord(id: UUID, existing: [UninstallRemainingRecord]) -> [UninstallRemainingRecord] {
        let records = existing.filter { $0.id != id }
        save(records)
        return records
    }

    func clear(existing: [UninstallRemainingRecord]) -> [UninstallRemainingRecord] {
        guard !existing.isEmpty else { return existing }
        let records: [UninstallRemainingRecord] = []
        save(records)
        return records
    }

    func removePaths(_ paths: Set<String>, existing: [UninstallRemainingRecord]) -> [UninstallRemainingRecord] {
        guard !paths.isEmpty else { return existing }
        let normalized = Set(paths.map(normalizedPath))

        let records = existing.compactMap { record -> UninstallRemainingRecord? in
            let filtered = record.issues.filter { !normalized.contains(normalizedPath($0.path)) }
            guard !filtered.isEmpty else { return nil }
            return UninstallRemainingRecord(
                id: record.id,
                appName: record.appName,
                bundleID: record.bundleID,
                updatedAt: record.updatedAt,
                issues: filtered
            )
        }

        save(records)
        return records
    }

    private func uniqueIssues(from issues: [UninstallVerifyIssue]) -> [UninstallRemainingIssueRecord] {
        var uniqueByPath: [String: UninstallRemainingIssueRecord] = [:]
        for issue in issues.sorted(by: { $0.sizeInBytes > $1.sizeInBytes }) {
            let path = normalizedPath(issue.url.path)
            guard uniqueByPath[path] == nil else { continue }
            uniqueByPath[path] = UninstallRemainingIssueRecord(
                path: path,
                sizeInBytes: issue.sizeInBytes,
                reason: issue.reason,
                risk: issue.risk
            )
        }
        return uniqueByPath.values.sorted { lhs, rhs in
            if lhs.sizeInBytes != rhs.sizeInBytes {
                return lhs.sizeInBytes > rhs.sizeInBytes
            }
            return lhs.path < rhs.path
        }
    }

    private func mergedRecords(
        appName: String,
        bundleID: String?,
        issues: [UninstallVerifyIssue],
        updatedAt: Date,
        existing: [UninstallRemainingRecord]
    ) -> [UninstallRemainingRecord] {
        var records = existing.filter { !matches($0, appName: appName, bundleID: bundleID) }

        let mappedIssues = uniqueIssues(from: issues)
        if !mappedIssues.isEmpty {
            records.insert(
                UninstallRemainingRecord(
                    appName: appName,
                    bundleID: bundleID,
                    updatedAt: updatedAt,
                    issues: mappedIssues
                ),
                at: 0
            )
        }

        if records.count > recordLimit {
            records = Array(records.prefix(recordLimit))
        }
        return records
    }

    private func matches(_ record: UninstallRemainingRecord, appName: String, bundleID: String?) -> Bool {
        if let bundleID, let recordBundleID = record.bundleID {
            return recordBundleID.caseInsensitiveCompare(bundleID) == .orderedSame
        }
        return record.appName.caseInsensitiveCompare(appName) == .orderedSame
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
