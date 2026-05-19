import AppKit
import Foundation
import Darwin

enum PermissionReadiness {
    case ready
    case folderAccessMissing
    case fullDiskAccessMissing
    case folderAndFullDiskMissing
}

@MainActor
final class AppPermissionService: ObservableObject {
    @Published private(set) var firstLaunchNeedsSetup = false
    @Published private(set) var hasFolderPermission = false
    @Published private(set) var hasFullDiskAccess = false
    @Published var permissionHint: String?
    private var permissionRefreshGeneration: UInt64 = 0

    private let hasCompletedOnboardingKey = "dray.permissions.onboarding.completed"
    init() {
        firstLaunchNeedsSetup = !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        refreshPermissionStatus(for: nil)
    }

    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        firstLaunchNeedsSetup = false
    }

    func refreshPermissionStatus(for url: URL?) {
        hasFolderPermission = Self.evaluateFolderAccess(for: url)
        hasFullDiskAccess = Self.evaluateFullDiskAccess()
    }

    func refreshPermissionStatusAsync(for url: URL?) {
        permissionRefreshGeneration &+= 1
        let generation = permissionRefreshGeneration

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let folderPermission = Self.evaluateFolderAccess(for: url)
            let fullDiskAccess = Self.evaluateFullDiskAccess()
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard generation == self.permissionRefreshGeneration else { return }
                self.hasFolderPermission = folderPermission
                self.hasFullDiskAccess = fullDiskAccess
            }
        }
    }

    func refreshFolderAccess(for url: URL?) {
        hasFolderPermission = Self.evaluateFolderAccess(for: url)
    }

    func refreshFullDiskAccess() {
        hasFullDiskAccess = Self.evaluateFullDiskAccess()
    }

    var readiness: PermissionReadiness {
        if hasFolderPermission && hasFullDiskAccess { return .ready }
        if !hasFolderPermission && !hasFullDiskAccess { return .folderAndFullDiskMissing }
        if !hasFolderPermission { return .folderAccessMissing }
        return .fullDiskAccessMissing
    }

    func canRunScan(target: URL?) -> Bool {
        refreshPermissionStatus(for: target)
        guard let target else {
            permissionHint = "No scan target selected."
            return false
        }
        if target.path == "/" && !hasFullDiskAccess {
            permissionHint = "Full Disk Access is required to scan the entire disk."
            return false
        }
        if !hasFolderPermission {
            permissionHint = "Grant folder access for the selected scan target."
            return false
        }
        return true
    }

    func canRunProtectedModule(actionName: String) -> Bool {
        refreshFullDiskAccess()
        guard hasFullDiskAccess else {
            permissionHint = "Full Disk Access is required for \(actionName)."
            return false
        }
        return true
    }

    func canModify(urls: [URL], actionName: String, requiresFullDisk: Bool = false) -> Bool {
        if requiresFullDisk && !canRunProtectedModule(actionName: actionName) {
            return false
        }
        let fm = FileManager.default
        for url in urls {
            let path = url.path
            if isSystemProtectedPath(path) {
                permissionHint = "System files are protected by macOS (SIP) and cannot be modified by DRay."
                return false
            }

            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started { url.stopAccessingSecurityScopedResource() }
            }

            if fm.fileExists(atPath: path) {
                if !fm.isDeletableFile(atPath: path) {
                    refreshFullDiskAccess()
                    if hasFullDiskAccess {
                        permissionHint = "Full Disk Access is granted, but the current user cannot delete \(url.lastPathComponent). Administrator authorization may be required. SIP-protected paths still cannot be modified."
                    } else {
                        permissionHint = "Additional permissions are required for \(actionName): \(url.lastPathComponent)."
                    }
                    return false
                }
            } else {
                let parent = url.deletingLastPathComponent().path
                if !fm.isWritableFile(atPath: parent) {
                    permissionHint = "No write access for \(actionName) at \(parent)."
                    return false
                }
            }
        }
        return true
    }

    private func isSystemProtectedPath(_ path: String) -> Bool {
        SystemPathProtection.isProtected(path)
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func restorePermissions() {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            permissionHint = "Failed to resolve bundle identifier for permissions reset."
            return
        }

        runTCCReset(service: "SystemPolicyAllFiles", bundleID: bundleID)
        openFullDiskAccessSettings()
        permissionHint = "Permissions were reset. Re-grant Full Disk Access for DRay and relaunch the app."
    }

    private nonisolated static func evaluateFolderAccess(for url: URL?) -> Bool {
        guard let url else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }

        if FileManager.default.isReadableFile(atPath: url.path) {
            return true
        }

        // Lightweight directory access probe (avoid full directory listing on large paths).
        if let dir = opendir(url.path) {
            closedir(dir)
            return true
        }

        return false
    }

    private nonisolated static func evaluateFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Safari/History.db"),
            home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        ]

        for candidate in candidates {
            if canReadPath(candidate) {
                return true
            }
        }
        return false
    }

    private nonisolated static func canReadPath(_ url: URL) -> Bool {
        let fm = FileManager.default
        let path = url.path
        guard fm.fileExists(atPath: path) else { return false }

        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }

        if fm.isReadableFile(atPath: path) {
            return true
        }

        let handle = try? FileHandle(forReadingFrom: url)
        do {
            try handle?.close()
            return handle != nil
        } catch {
            return false
        }
    }

    nonisolated private func runTCCReset(service: String, bundleID: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleID]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }
}
