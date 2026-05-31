import Foundation

enum PathSafetyClassification: String, Codable, Sendable {
    case systemProtected
    case adminSensitive
    case userData
    case cacheSafe
    case appBundle
    case remnant
    case unknown
}

enum PathOperationDisposition: String, Codable, Sendable {
    case standardTrashAllowed
    case adminTrashAllowed
    case forceRemoveAllowedOnlyWithHighRiskMode
    case manualOnly
}

struct PathSafetyAssessment: Sendable {
    let path: String
    let classification: PathSafetyClassification
    let disposition: PathOperationDisposition
    let rationale: String

    var standardTrashAllowed: Bool {
        disposition == .standardTrashAllowed
    }

    var adminTrashAllowed: Bool {
        disposition == .adminTrashAllowed || disposition == .forceRemoveAllowedOnlyWithHighRiskMode
    }

    var forceRemoveAllowedOnlyWithHighRiskMode: Bool {
        disposition == .forceRemoveAllowedOnlyWithHighRiskMode
    }

    var manualOnly: Bool {
        disposition == .manualOnly
    }

    var shouldSkipForSafeCleanup: Bool {
        manualOnly || classification == .adminSensitive
    }
}

enum PathSafetyPolicy {
    private static let systemProtectedPrefixes = [
        "/System",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/usr/lib",
        "/usr/libexec",
        "/usr/share",
        "/private/etc"
    ]

    private static let adminSensitivePrefixes = [
        "/Library/LaunchDaemons",
        "/Library/PrivilegedHelperTools",
        "/Library/StartupItems",
        "/Library/LaunchAgents",
        "/Library/Application Support",
        "/Library/Caches",
        "/Library/Preferences",
        "/Library/Logs",
        "/private/var"
    ]

    private static let userCacheMarkers = [
        "/Library/Caches/",
        "/Library/Logs/",
        "/Library/Developer/Xcode/DerivedData/"
    ]

    static func assess(_ rawPath: String) -> PathSafetyAssessment {
        let path = standardizedPath(rawPath)
        if path == "/" {
            return PathSafetyAssessment(
                path: path,
                classification: .systemProtected,
                disposition: .manualOnly,
                rationale: "Root volume is not a removable target."
            )
        }

        if matchesAny(path, prefixes: systemProtectedPrefixes) || path == "/usr" {
            return PathSafetyAssessment(
                path: path,
                classification: .systemProtected,
                disposition: .manualOnly,
                rationale: "SIP/system-owned path; DRay must not remove it."
            )
        }

        if path.hasPrefix("/Applications/"), path.hasSuffix(".app") {
            return PathSafetyAssessment(
                path: path,
                classification: .appBundle,
                disposition: .forceRemoveAllowedOnlyWithHighRiskMode,
                rationale: "Application bundle can require admin fallback or high-risk force removal."
            )
        }

        if matchesAny(path, prefixes: adminSensitivePrefixes) {
            return PathSafetyAssessment(
                path: path,
                classification: .adminSensitive,
                disposition: .adminTrashAllowed,
                rationale: "System-level app support path; admin cleanup may be required."
            )
        }

        if isUserPreferencesPath(path) {
            return PathSafetyAssessment(
                path: path,
                classification: .userData,
                disposition: .manualOnly,
                rationale: "Active user/macOS preference state; Smart Care must not remove it."
            )
        }

        if isHomePath(path), userCacheMarkers.contains(where: { path.contains($0) }) {
            return PathSafetyAssessment(
                path: path,
                classification: .cacheSafe,
                disposition: .standardTrashAllowed,
                rationale: "User cache/log/build artifact path."
            )
        }

        if isHomePath(path), path.contains("/Library/") {
            return PathSafetyAssessment(
                path: path,
                classification: .remnant,
                disposition: .standardTrashAllowed,
                rationale: "User Library app remnant path."
            )
        }

        if isHomePath(path) {
            return PathSafetyAssessment(
                path: path,
                classification: .userData,
                disposition: .standardTrashAllowed,
                rationale: "User-owned path."
            )
        }

        if path.hasPrefix("/Applications/") {
            return PathSafetyAssessment(
                path: path,
                classification: .appBundle,
                disposition: .adminTrashAllowed,
                rationale: "Application support path under /Applications."
            )
        }

        if path.hasPrefix("/Library/") || path.hasPrefix("/usr/local/") {
            return PathSafetyAssessment(
                path: path,
                classification: .adminSensitive,
                disposition: .adminTrashAllowed,
                rationale: "Admin-owned non-SIP path."
            )
        }

        return PathSafetyAssessment(
            path: path,
            classification: .unknown,
            disposition: .adminTrashAllowed,
            rationale: "Unknown non-SIP path; require explicit operation context."
        )
    }

    static func isProtected(_ path: String) -> Bool {
        let assessment = assess(path)
        return assessment.classification == .systemProtected && assessment.manualOnly
    }

    static func shouldSkipForSafeCleanup(_ path: String) -> Bool {
        assess(path).shouldSkipForSafeCleanup
    }

    static func shouldSkipForDefaultCleanup(_ rawPath: String) -> Bool {
        let path = standardizedPath(rawPath)
        let assessment = assess(path)
        if assessment.shouldSkipForSafeCleanup {
            return true
        }
        if isDefaultSensitiveUserLibraryPath(path) {
            return true
        }
        if isCriticalPreferenceDomainPath(path) {
            return true
        }
        return false
    }

    static func isUserPreferenceStatePath(_ rawPath: String) -> Bool {
        isUserPreferencesPath(standardizedPath(rawPath))
    }

    private static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func matchesAny(_ path: String, prefixes: [String]) -> Bool {
        prefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func isHomePath(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        return path == home || path.hasPrefix(home + "/")
    }

    private static func isUserPreferencesPath(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let preferencesRoot = home + "/Library/Preferences"
        return path == preferencesRoot || path.hasPrefix(preferencesRoot + "/")
    }

    private static func isDefaultSensitiveUserLibraryPath(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let roots = [
            "Library/Accounts",
            "Library/Application Scripts",
            "Library/Application Support",
            "Library/Application Support/AddressBook",
            "Library/Application Support/CallHistoryDB",
            "Library/Application Support/CloudDocs",
            "Library/Application Support/com.apple.sharedfilelist",
            "Library/Application Support/Dock",
            "Library/Application Support/Knowledge",
            "Library/Application Support/NotificationCenter",
            "Library/Autosave Information",
            "Library/Calendars",
            "Library/CloudKit",
            "Library/Containers",
            "Library/Cookies",
            "Library/Group Containers",
            "Library/HTTPStorages",
            "Library/IdentityServices",
            "Library/Keyboard Layouts",
            "Library/Keychains",
            "Library/LaunchAgents",
            "Library/Mail",
            "Library/Messages",
            "Library/Metadata",
            "Library/Mobile Documents",
            "Library/Passes",
            "Library/Personas",
            "Library/Photos",
            "Library/Reminders",
            "Library/Safari",
            "Library/Saved Application State",
            "Library/Screen Savers",
            "Library/Services",
            "Library/Sharing",
            "Library/Sounds",
            "Library/Spelling",
            "Library/Suggestions",
            "Library/SyncedPreferences",
            "Library/UserNotifications",
            "Library/WebKit",
            "Library/VoiceTrigger"
        ]

        for relativeRoot in roots {
            let root = home + "/" + relativeRoot
            if path == root || path.hasPrefix(root + "/") {
                return true
            }
        }

        let mobileSyncBackup = home + "/Library/Application Support/MobileSync/Backup"
        if path == mobileSyncBackup || path.hasPrefix(mobileSyncBackup + "/") {
            return true
        }

        return false
    }

    private static func isCriticalPreferenceDomainPath(_ path: String) -> Bool {
        guard isUserPreferencesPath(path) else { return false }
        let domain = URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if domain.isEmpty {
            return true
        }
        if domain == ".globalpreferences" || domain == "globalpreferences" || domain == "nsglobaldomain" {
            return true
        }
        return domain.hasPrefix("com.apple.") || domain.hasPrefix("apple.")
    }
}
