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
        assess(path).manualOnly
    }

    static func shouldSkipForSafeCleanup(_ path: String) -> Bool {
        assess(path).shouldSkipForSafeCleanup
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
}
