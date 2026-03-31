import Foundation
import Darwin

struct MenuBarLoginAgentService {
    private let label = "com.squazaryu.dray.menubar"

    private var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: false)
    }

    func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return installAgent()
        }
        return uninstallAgent()
    }

    @discardableResult
    private func installAgent() -> Bool {
        guard let helperPath = resolveHelperExecutablePath() else { return false }
        let appBundlePath = resolveAppBundlePath()
        let parent = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        var programArguments: [String] = [helperPath]
        if let appBundlePath {
            programArguments += ["--app-path", appBundlePath]
        }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua"
        ]

        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ) else {
            return false
        }

        do {
            try data.write(to: plistURL, options: [.atomic])
        } catch {
            return false
        }

        _ = runLaunchctl(arguments: ["bootout", "gui/\(currentUID())", plistURL.path])
        return runLaunchctl(arguments: ["bootstrap", "gui/\(currentUID())", plistURL.path])
    }

    @discardableResult
    private func uninstallAgent() -> Bool {
        _ = runLaunchctl(arguments: ["bootout", "gui/\(currentUID())", plistURL.path])
        do {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
            return true
        } catch {
            return false
        }
    }

    private func resolveHelperExecutablePath() -> String? {
        guard let bundlePath = Bundle.main.bundlePath as String?,
              !bundlePath.isEmpty else { return nil }
        let helper = (bundlePath as NSString).appendingPathComponent("Contents/Helpers/DRayMenuBarHelper")
        guard FileManager.default.isExecutableFile(atPath: helper) else { return nil }
        return helper
    }

    private func resolveAppBundlePath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.hasSuffix(".app") {
            return bundlePath
        }
        guard let executable = Bundle.main.executableURL?.path else { return nil }
        let marker = "/Contents/MacOS/"
        if let range = executable.range(of: marker) {
            return String(executable[..<range.lowerBound])
        }
        return nil
    }

    private func currentUID() -> Int {
        Int(getuid())
    }

    private func runLaunchctl(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
