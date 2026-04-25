import SwiftUI
import AppKit

@MainActor
final class MenuBarPopupModel: ObservableObject {
    let appPath: String
    @Published private(set) var launchAtLoginEnabled = false
    @Published var reliefResultMessage: String?

    let bridge: DRayMainBridge
    private let loginAgentService: MenuBarLoginAgentService
    private let reliefService = LoadReliefService()
    private let batteryService = BatteryDiagnosticsService()
    private var cachedBatterySnapshot: (timestamp: Date, snapshot: BatteryDiagnosticsSnapshot)?
    private let batteryDetailsCacheTTL: TimeInterval = 2.0

    init(config: HelperConfig) {
        appPath = config.appPath
        let helperPath = CommandLine.arguments.first ?? ""
        bridge = DRayMainBridge(appPath: config.appPath)
        loginAgentService = MenuBarLoginAgentService(appPath: config.appPath, helperPath: helperPath)
        refreshLaunchAtLoginStatus()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = loginAgentService.isEnabled()
    }

    func toggleLaunchAtLogin() {
        _ = loginAgentService.setEnabled(!launchAtLoginEnabled)
        refreshLaunchAtLoginStatus()
    }

    func open(section: AppSection, action: AppLaunchAction? = nil) {
        bridge.open(section: section, action: action)
    }

    func openMain() {
        bridge.open(section: .smartCare, action: nil)
    }

    func quitCompletely() {
        bridge.requestFullQuit()
        NSApp.terminate(nil)
    }

    func reduceCPU(consumers: [ProcessConsumer], limit: Int = 3) {
        let result = reliefService.reduceCPU(consumers: consumers, limit: limit)
        reliefResultMessage = formatReliefResult(result)
    }

    func reduceMemory(consumers: [ProcessConsumer], limit: Int = 3) {
        let result = reliefService.reduceMemory(consumers: consumers, limit: limit)
        reliefResultMessage = formatReliefResult(result)
    }

    func restorePriorities() {
        let result = reliefService.restore(limit: 5)
        reliefResultMessage = formatReliefResult(result)
    }

    var canRestorePriorities: Bool {
        reliefService.hasAdjustments
    }

    func fetchBatteryDetails(force: Bool = false) -> BatteryDiagnosticsSnapshot {
        let now = Date()
        if !force,
           let cachedBatterySnapshot,
           now.timeIntervalSince(cachedBatterySnapshot.timestamp) <= batteryDetailsCacheTTL {
            return cachedBatterySnapshot.snapshot
        }
        let snapshot = batteryService.fetchSnapshot()
        cachedBatterySnapshot = (timestamp: now, snapshot: snapshot)
        return snapshot
    }

    private func formatReliefResult(_ result: LoadReliefResult) -> String {
        let adjustedText = result.adjusted.isEmpty ? "0" : "\(result.adjusted.count): " + result.adjusted.joined(separator: ", ")
        let failedText = result.failed.isEmpty ? "0" : "\(result.failed.count): " + result.failed.joined(separator: ", ")
        let skippedText = result.skipped.isEmpty ? "0" : "\(result.skipped.count): " + result.skipped.joined(separator: ", ")
        return "Adjusted \(adjustedText)\nFailed \(failedText)\nSkipped \(skippedText)"
    }
}

@MainActor
final class MenuBarHelperAppDelegate: NSObject, NSApplicationDelegate {
    private var workspaceActivationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.accessory)
        guard HelperSingleInstanceLock.acquire() else {
            NSApp.terminate(nil)
            return
        }

        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
            let helperBundleID = Bundle.main.bundleIdentifier
            if frontmost.bundleIdentifier != helperBundleID {
                Task { @MainActor in
                    self.dismissTransientUI()
                }
            }
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        dismissTransientUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceActivationObserver = nil
        }
        AppBundleIconThemeSynchronizer.shared.stop()
    }

    private func dismissTransientUI() {
        NotificationCenter.default.post(name: .helperDismissTransientUI, object: nil)
    }
}

@main
struct DRayMenuBarHelperApp: App {
    @NSApplicationDelegateAdaptor(MenuBarHelperAppDelegate.self) private var appDelegate
    private let config = HelperConfig(arguments: CommandLine.arguments)
    @StateObject private var model: MenuBarPopupModel
    @StateObject private var monitor: LiveSystemMetricsMonitor

    init() {
        let config = HelperConfig(arguments: CommandLine.arguments)
        let liveMonitor = LiveSystemMetricsMonitor(updateInterval: 1.0, heavySamplePeriod: 4.0)
        liveMonitor.setConsumerSamplingEnabled(false)
        _model = StateObject(wrappedValue: MenuBarPopupModel(config: config))
        _monitor = StateObject(wrappedValue: liveMonitor)
        AppBundleIconThemeSynchronizer.shared.start(appPath: config.appPath)
        liveMonitor.start()
        if let startupSection = config.startupSection {
            let bridge = DRayMainBridge(appPath: config.appPath)
            bridge.open(section: startupSection, action: nil)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopupView(model: model, monitor: monitor)
        } label: {
            MenuBarStatusIcon(monitor: monitor)
        }
        #if DRAY_HELPER_MENU_STYLE_MENU
        .menuBarExtraStyle(.menu)
        #else
        .menuBarExtraStyle(.window)
        #endif
    }
}

