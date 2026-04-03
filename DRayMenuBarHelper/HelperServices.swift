import Foundation
import AppKit
import Darwin

@MainActor
enum HelperSingleInstanceLock {
    private static var lockFD: Int32 = -1

    static func acquire() -> Bool {
        if lockFD != -1 { return true }
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("com.squazaryu.dray.menubar.lock")
        let fd = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return false }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        lockFD = fd
        return true
    }
}

struct MenuBarLoginAgentService {
    private let label = "com.squazaryu.dray.menubar"
    private let appPath: String
    private let helperPath: String

    init(appPath: String, helperPath: String) {
        self.appPath = appPath
        self.helperPath = helperPath
    }

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
        enabled ? installAgent() : uninstallAgent()
    }

    @discardableResult
    private func installAgent() -> Bool {
        guard FileManager.default.isExecutableFile(atPath: helperPath) else { return false }
        let parent = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let programArguments = [helperPath, "--app-path", appPath]
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua"
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
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

struct DRayMainBridge {
    let appPath: String

    func open(section: AppSection? = nil, action: AppLaunchAction? = nil) {
        let isRunning = runningApp != nil
        postOpenNotification(section: section, action: action)
        if isRunning {
            runningApp?.activate(options: [])
            return
        }

        var args = ["-a", appPath, "--args"]
        if let section {
            args += ["--open-section", section.rawValue]
        }
        if let action {
            args += ["--run-action", action.rawValue]
        }
        _ = runProcess("/usr/bin/open", arguments: args, wait: false)
    }

    func requestFullQuit() {
        DistributedNotificationCenter.default().postNotificationName(
            AppIPC.quitCompletelyName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        runningApp?.terminate()
    }

    private var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.squazaryu.DRay").first
    }

    private func postOpenNotification(section: AppSection?, action: AppLaunchAction?) {
        var payload: [String: String] = [:]
        if let section {
            payload[AppIPC.sectionKey] = section.rawValue
        }
        if let action {
            payload[AppIPC.actionKey] = action.rawValue
        }
        DistributedNotificationCenter.default().postNotificationName(
            AppIPC.openSectionName,
            object: nil,
            userInfo: payload.isEmpty ? nil : payload,
            deliverImmediately: true
        )
    }

    @discardableResult
    private func runProcess(_ launchPath: String, arguments: [String], wait: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            if wait {
                process.waitUntilExit()
                return process.terminationStatus == 0
            }
            return true
        } catch {
            return false
        }
    }
}

@MainActor
final class AppBundleIconThemeSynchronizer {
    static let shared = AppBundleIconThemeSynchronizer()

    private let themeNotification = Notification.Name("AppleInterfaceThemeChangedNotification")
    private var appPath: String?
    private var observer: NSObjectProtocol?
    private var lastIconName: String?

    private init() {}

    func start(appPath: String) {
        let normalizedPath = (appPath as NSString).standardizingPath
        self.appPath = normalizedPath
        applyCurrentThemeIcon(force: true)
        if observer != nil { return }

        observer = DistributedNotificationCenter.default().addObserver(
            forName: themeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyCurrentThemeIcon(force: false)
            }
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
    }

    func applyCurrentThemeIcon(force: Bool) {
        guard let appPath else { return }

        let preferredName = currentThemeIsDark ? "DRayDark" : "DRayLight"
        if !force, lastIconName == preferredName { return }

        let resourceRoot = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources", isDirectory: true)
        let candidates = [preferredName, "DRay"]
        guard
            let iconURL = candidates
                .map({ resourceRoot.appendingPathComponent("\($0).icns", isDirectory: false) })
                .first(where: { FileManager.default.fileExists(atPath: $0.path) }),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        guard NSWorkspace.shared.setIcon(icon, forFile: appPath, options: []) else {
            return
        }
        lastIconName = preferredName
    }

    private var currentThemeIsDark: Bool {
        let appearance = NSApplication.shared.effectiveAppearance
        if let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
            return match == .darkAqua
        }
        if let style = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String {
            return style.caseInsensitiveCompare("dark") == .orderedSame
        }
        return false
    }
}

struct LoadReliefResult {
    let adjusted: [String]
    let skipped: [String]
    let failed: [String]
}

private struct ProcessPriorityAdjustment {
    let pid: Int32
    let name: String
    let baselineNice: Int32
}

@MainActor
final class LoadReliefService {
    private var priorityAdjustments: [ProcessPriorityAdjustment] = []

    var hasAdjustments: Bool {
        !priorityAdjustments.isEmpty
    }

    func reduceCPU(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        adjustTop(consumers.sorted { $0.cpuPercent > $1.cpuPercent }, limit: limit)
    }

    func reduceMemory(consumers: [ProcessConsumer], limit: Int = 3) -> LoadReliefResult {
        adjustTop(consumers.sorted { $0.memoryMB > $1.memoryMB }, limit: limit)
    }

    func restore(limit: Int = 5) -> LoadReliefResult {
        guard !priorityAdjustments.isEmpty else {
            return LoadReliefResult(adjusted: [], skipped: [], failed: [])
        }

        var restored: [String] = []
        var skipped: [String] = []
        var failed: [String] = []
        let targets = Array(priorityAdjustments.prefix(max(1, limit)))

        for target in targets {
            guard canAdjustPriority(forPID: target.pid) else {
                skipped.append(target.name)
                priorityAdjustments.removeAll { $0.pid == target.pid }
                continue
            }
            let niceValue = String(target.baselineNice)
            let reniceOK = runCommand("/usr/bin/renice", arguments: [niceValue, "-p", String(target.pid)])
            let policyOK = runCommand("/usr/bin/taskpolicy", arguments: ["-B", "-p", String(target.pid)])
            if reniceOK || policyOK {
                restored.append(target.name)
                priorityAdjustments.removeAll { $0.pid == target.pid }
            } else {
                failed.append(target.name)
            }
        }
        return LoadReliefResult(adjusted: restored, skipped: skipped, failed: failed)
    }

    private func adjustTop(_ consumers: [ProcessConsumer], limit: Int) -> LoadReliefResult {
        var adjusted: [String] = []
        var skipped: [String] = []
        var failed: [String] = []
        var processed = 0

        for consumer in consumers where processed < max(1, limit) {
            guard canAdjustPriority(forPID: consumer.pid) else {
                skipped.append(consumer.name)
                continue
            }
            processed += 1
            let baseline = baselineNiceValue(forPID: consumer.pid) ?? 0
            let reniceOK = runCommand("/usr/bin/renice", arguments: ["+10", "-p", String(consumer.pid)])
            let backgroundOK = runCommand("/usr/bin/taskpolicy", arguments: ["-b", "-p", String(consumer.pid)])
            if reniceOK || backgroundOK {
                adjusted.append(consumer.name)
                if let existing = priorityAdjustments.firstIndex(where: { $0.pid == consumer.pid }) {
                    priorityAdjustments[existing] = ProcessPriorityAdjustment(
                        pid: consumer.pid,
                        name: consumer.name,
                        baselineNice: priorityAdjustments[existing].baselineNice
                    )
                } else {
                    priorityAdjustments.append(
                        ProcessPriorityAdjustment(pid: consumer.pid, name: consumer.name, baselineNice: baseline)
                    )
                }
            } else {
                failed.append(consumer.name)
            }
        }
        return LoadReliefResult(adjusted: adjusted, skipped: skipped, failed: failed)
    }

    private func canAdjustPriority(forPID pid: Int32) -> Bool {
        guard pid > 1 else { return false }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return false }

        if kill(pid, 0) != 0 {
            switch errno {
            case ESRCH, EPERM:
                return false
            default:
                break
            }
        }

        if let app = NSRunningApplication(processIdentifier: pid),
           let bundleID = app.bundleIdentifier,
           bundleID.hasPrefix("com.apple.") {
            return false
        }

        return true
    }

    private func baselineNiceValue(forPID pid: Int32) -> Int32? {
        errno = 0
        let value = getpriority(PRIO_PROCESS, UInt32(pid))
        if errno != 0 {
            return nil
        }
        return value
    }

    private func runCommand(_ launchPath: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
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
