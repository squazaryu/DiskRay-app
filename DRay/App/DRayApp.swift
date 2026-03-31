import SwiftUI
import AppKit

enum AppRunMode: String {
    case standard
}

struct AppLaunchContext {
    let mode: AppRunMode
    let startupSection: AppSection?
    let startupAction: AppLaunchAction?

    init(arguments: [String]) {
        var startupSection: AppSection?
        var startupAction: AppLaunchAction?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--open-section":
                if index + 1 < arguments.count {
                    startupSection = AppSection(rawValue: arguments[index + 1])
                    index += 1
                }
            case "--run-action":
                if index + 1 < arguments.count {
                    startupAction = AppLaunchAction(rawValue: arguments[index + 1])
                    index += 1
                }
            default:
                break
            }
            index += 1
        }

        self.mode = .standard
        self.startupSection = startupSection
        self.startupAction = startupAction
    }
}

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()
    private(set) var launchContext = AppLaunchContext(arguments: [])

    func configure(_ context: AppLaunchContext) {
        launchContext = context
    }
}

@MainActor
final class AppTerminationCoordinator {
    static let shared = AppTerminationCoordinator()
    private(set) var allowTermination = false

    func closeToMenuBar() {
        guard prepareTerminationToMenuBar() else {
            NSSound.beep()
            return
        }
        NSApp.terminate(nil)
    }

    func showMainWindow(targetSection: AppSection? = nil) {
        _ = NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        AppLogger.telemetry.info("Main window shown")
        if let targetSection {
            AppLogger.telemetry.info("Main window target section: \(targetSection.rawValue, privacy: .public)")
        }
    }

    func terminateCompletely() {
        allowTermination = true
        terminateMenuBarHelperProcesses()
        NSApp.terminate(nil)
    }

    @discardableResult
    func prepareTerminationToMenuBar() -> Bool {
        if allowTermination { return true }
        allowTermination = true
        let launched = launchMenuBarHelperIfNeeded()
        if !launched {
            allowTermination = false
        }
        return launched
    }

    @discardableResult
    private func launchMenuBarHelperIfNeeded(openSection: AppSection? = nil) -> Bool {
        if isHelperRunning() { return true }
        guard let helperPath = resolveHelperExecutablePath() else {
            AppLogger.telemetry.error("Helper executable was not found in app bundle")
            return false
        }

        var arguments: [String] = []
        if let appPath = resolveAppBundlePath() {
            arguments += ["--app-path", appPath]
        }
        if let openSection {
            arguments += ["--open-section", openSection.rawValue]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: helperPath)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.standardInput = nil

        do {
            try process.run()
            AppLogger.telemetry.info("Spawned menu bar helper process")
            return true
        } catch {
            AppLogger.telemetry.error("Failed to spawn menu bar helper process: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func isHelperRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "DRayMenuBarHelper"]
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

    private func terminateMenuBarHelperProcesses() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-x", "DRayMenuBarHelper"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogger.telemetry.error("Failed to terminate helper processes: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resolveHelperExecutablePath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        guard bundlePath.hasSuffix(".app") else { return nil }
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
        guard let range = executable.range(of: marker) else { return nil }
        return String(executable[..<range.lowerBound])
    }
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashTelemetryService.shared.beginSession(mode: AppRuntime.shared.launchContext.mode)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppTerminationCoordinator.shared.allowTermination {
            return .terminateNow
        }
        AppTerminationCoordinator.shared.prepareTerminationToMenuBar()
        return AppTerminationCoordinator.shared.allowTermination ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        CrashTelemetryService.shared.endSession()
    }
}

@main
struct DRayApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    private let launchContext: AppLaunchContext
    @StateObject private var model: RootViewModel
    @State private var didApplyLaunchAction = false

    init() {
        let context = AppLaunchContext(arguments: CommandLine.arguments)
        launchContext = context
        AppRuntime.shared.configure(context)

        let rootModel = RootViewModel(initialSection: context.startupSection)
        AppIPCReceiver.shared.configure(model: rootModel)
        _model = StateObject(wrappedValue: rootModel)
        AppLogger.telemetry.info("App launched")
    }

    @CommandsBuilder
    private var appCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About DRay") {
                NSApp.orderFrontStandardAboutPanel(nil)
                AppLogger.telemetry.info("About panel opened")
            }
        }
        CommandGroup(replacing: .appTermination) {
            Button("Quit DRay (Keep Menu Bar)") {
                AppTerminationCoordinator.shared.closeToMenuBar()
            }
            .keyboardShortcut("q")

            Divider()

            Button("Quit DRay Completely", role: .destructive) {
                AppTerminationCoordinator.shared.terminateCompletely()
            }
        }
        CommandMenu("DRay") {
            Button("Hide Main Window") {
                NSApp.keyWindow?.orderOut(nil)
            }
            .keyboardShortcut("w")

            Button("Show Main Window") {
                AppTerminationCoordinator.shared.showMainWindow(targetSection: .smartCare)
            }

            Divider()

            Button("Quit DRay Completely", role: .destructive) {
                AppTerminationCoordinator.shared.terminateCompletely()
            }
        }
    }

    var body: some Scene {
        WindowGroup("DRay") {
            RootView(model: model)
                .frame(minWidth: 1024, minHeight: 680)
                .onAppear {
                    AppLogger.telemetry.info("Root view appeared")
                    applyLaunchActionIfNeeded()
                }
        }
        .windowResizability(.contentSize)
        .commands { appCommands }
    }

    private func applyLaunchActionIfNeeded() {
        guard !didApplyLaunchAction else { return }
        didApplyLaunchAction = true
        guard let startupAction = launchContext.startupAction else { return }
        AppIPCReceiver.shared.execute(action: startupAction, model: model)
    }
}
