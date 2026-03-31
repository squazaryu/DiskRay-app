import AppKit
import Foundation

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
        refreshFolderAccess(for: url)
        refreshFullDiskAccess()
    }

    func refreshFolderAccess(for url: URL?) {
        guard let url else {
            hasFolderPermission = false
            return
        }
        hasFolderPermission = canReadDirectory(url)
    }

    func refreshFullDiskAccess() {
        hasFullDiskAccess = canReadProtectedLocation()
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
            if path.hasPrefix("/System/") || path == "/System" {
                permissionHint = "System files are protected and cannot be modified by DRay."
                return false
            }

            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started { url.stopAccessingSecurityScopedResource() }
            }

            if fm.fileExists(atPath: path) {
                if !fm.isDeletableFile(atPath: path) {
                    permissionHint = "Additional permissions are required for \(actionName): \(url.lastPathComponent)."
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

    private func canReadDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }

        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return true
        } catch {
            return false
        }
    }

    private func canReadProtectedLocation() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Mail"),
            home.appendingPathComponent("Library/Safari")
        ]

        for candidate in candidates {
            if canReadPath(candidate) {
                return true
            }
        }
        return false
    }

    private func canReadPath(_ url: URL) -> Bool {
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

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                _ = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                return true
            } else {
                let handle = try FileHandle(forReadingFrom: url)
                try handle.close()
                return true
            }
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
