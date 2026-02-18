import AppKit
import Foundation

@MainActor
final class AppPermissionService: ObservableObject {
    @Published private(set) var firstLaunchNeedsSetup = false
    @Published private(set) var hasFolderPermission = false
    @Published var permissionHint: String?

    private let hasCompletedOnboardingKey = "dray.permissions.onboarding.completed"

    init() {
        firstLaunchNeedsSetup = !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }

    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        firstLaunchNeedsSetup = false
    }

    func refreshFolderAccess(for url: URL?) {
        guard let url else {
            hasFolderPermission = false
            return
        }
        hasFolderPermission = canReadDirectory(url)
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func restorePermissions() {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            permissionHint = "Не удалось определить bundle id для сброса прав."
            return
        }

        runTCCReset(service: "SystemPolicyAllFiles", bundleID: bundleID)
        openFullDiskAccessSettings()
        permissionHint = "Доступы сброшены. Выдай DRay доступ в Full Disk Access и перезапусти приложение."
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
