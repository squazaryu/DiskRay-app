import Foundation

enum SystemPathProtection {
    static let protectedPrefixes: [String] = [
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

    static func isProtected(_ path: String) -> Bool {
        PathSafetyPolicy.isProtected(path)
    }
}
