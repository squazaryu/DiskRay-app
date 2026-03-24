import Foundation

struct UserLogsAnalyzer: CleanupAnalyzer {
    let key = "user_logs"
    let title = "User Logs"
    let description = "Old log files from ~/Library/Logs"
    let isSafeByDefault = true

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        let items = CleanupFileEnumerator.collectFiles(in: root, olderThanDays: 14, excludedPrefixes: excludedPrefixes)
        return CleanupCategoryResult(key: key, title: title, description: description, isSafeByDefault: isSafeByDefault, riskLevel: .low, items: items)
    }
}

struct UserCachesAnalyzer: CleanupAnalyzer {
    let key = "user_caches"
    let title = "User Caches"
    let description = "Cache files from ~/Library/Caches"
    let isSafeByDefault = true

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        let items = CleanupFileEnumerator.collectFiles(in: root, olderThanDays: 7, excludedPrefixes: excludedPrefixes)
        return CleanupCategoryResult(key: key, title: title, description: description, isSafeByDefault: isSafeByDefault, riskLevel: .low, items: items)
    }
}

struct OldDownloadsAnalyzer: CleanupAnalyzer {
    let key = "old_downloads"
    let title = "Old Downloads"
    let description = "Files in ~/Downloads older than 30 days"
    let isSafeByDefault = false

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let items = CleanupFileEnumerator.collectFiles(in: root, olderThanDays: 30, excludedPrefixes: excludedPrefixes)
        return CleanupCategoryResult(key: key, title: title, description: description, isSafeByDefault: isSafeByDefault, riskLevel: .medium, items: items)
    }
}

struct XcodeDerivedDataAnalyzer: CleanupAnalyzer {
    let key = "xcode_derived_data"
    let title = "Xcode DerivedData"
    let description = "Build artifacts from ~/Library/Developer/Xcode/DerivedData"
    let isSafeByDefault = true

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
        let items = CleanupFileEnumerator.collectFiles(in: root, olderThanDays: 2, excludedPrefixes: excludedPrefixes)
        return CleanupCategoryResult(key: key, title: title, description: description, isSafeByDefault: isSafeByDefault, riskLevel: .low, items: items)
    }
}

struct IOSBackupsAnalyzer: CleanupAnalyzer {
    let key = "ios_backups"
    let title = "iOS Backups"
    let description = "Local iPhone/iPad backups"
    let isSafeByDefault = false

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MobileSync/Backup")
        let items = CleanupFileEnumerator.collectFiles(in: root, olderThanDays: 14, excludedPrefixes: excludedPrefixes)
        return CleanupCategoryResult(key: key, title: title, description: description, isSafeByDefault: isSafeByDefault, riskLevel: .high, items: items)
    }
}

struct MailDownloadsAnalyzer: CleanupAnalyzer {
    let key = "mail_downloads"
    let title = "Mail Downloads"
    let description = "Attachments saved by Apple Mail"
    let isSafeByDefault = false

    func analyze(excludedPrefixes: [String]) async -> CleanupCategoryResult {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads")
        let items = CleanupFileEnumerator.collectFiles(in: root, olderThanDays: 30, excludedPrefixes: excludedPrefixes)
        return CleanupCategoryResult(key: key, title: title, description: description, isSafeByDefault: isSafeByDefault, riskLevel: .medium, items: items)
    }
}

enum CleanupFileEnumerator {
    static func collectFiles(in root: URL, olderThanDays days: Int, excludedPrefixes: [String]) -> [CleanupItem] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return []
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        var result: [CleanupItem] = []

        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            if excludedPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                continue
            }
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isDirectory != true else { continue }
            guard let modified = values.contentModificationDate, modified < cutoff else { continue }
            let size = Int64(values.fileSize ?? 0)
            result.append(CleanupItem(url: fileURL, sizeInBytes: size))
        }

        return result.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }
}
