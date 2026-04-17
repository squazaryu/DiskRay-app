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

    func fetchBatteryDetails() -> BatteryDiagnosticsSnapshot {
        batteryService.fetchSnapshot()
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

private struct MenuBarStatusIcon: View {
    @ObservedObject var monitor: LiveSystemMetricsMonitor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            if let percent = monitor.snapshot.batteryLevelPercent {
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("BAT")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            if monitor.snapshot.batteryIsCharging == true {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .foregroundStyle(colorScheme == .dark ? .white : .black)
    }
}

private struct MenuBarPopupView: View {
    @ObservedObject var model: MenuBarPopupModel
    @ObservedObject var monitor: LiveSystemMetricsMonitor
    @Environment(\.colorScheme) private var colorScheme

    @State private var showHealthDetails = false
    @State private var showBatteryDetails = false
    @State private var batterySnapshot: BatteryDiagnosticsSnapshot?
    @State private var isBatteryDetailsLoading = false
    @State private var batteryDetailsError: String?
    @State private var suppressBatteryDetailsOpenUntil = Date.distantPast
    @State private var pendingReliefAction: ReliefAction?
    @State private var showReliefConfirm = false
    private let batteryRefreshTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            cardsGrid
            recommendationCard
            consumersSection
            footer
        }
        .padding(14)
        .background(shellBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(width: 432)
        .onReceive(NotificationCenter.default.publisher(for: .helperDismissTransientUI)) { _ in
            showHealthDetails = false
            showBatteryDetails = false
            showReliefConfirm = false
            pendingReliefAction = nil
        }
        .onAppear {
            monitor.setConsumerSamplingEnabled(true, sampleImmediately: true)
        }
        .onDisappear {
            showHealthDetails = false
            showBatteryDetails = false
            showReliefConfirm = false
            pendingReliefAction = nil
            monitor.setConsumerSamplingEnabled(false)
        }
        .onChange(of: showBatteryDetails) {
            if !showBatteryDetails {
                suppressBatteryDetailsOpenUntil = Date().addingTimeInterval(0.45)
            }
        }
        .onReceive(batteryRefreshTimer) { _ in
            guard showBatteryDetails else { return }
            loadBatteryDetails()
        }
        .overlay(alignment: .bottom) {
            if let message = model.reliefResultMessage {
                reliefResultBanner(message)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if showReliefConfirm {
                reliefConfirmOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .overlay {
            if showBatteryDetails {
                ZStack {
                    Color.black.opacity(colorScheme == .dark ? 0.34 : 0.18)
                        .ignoresSafeArea()
                        .allowsHitTesting(true)

                    BatteryDetailsSheetView(
                        snapshot: batterySnapshot,
                        isLoading: isBatteryDetailsLoading,
                        errorText: batteryDetailsError,
                        onRefresh: loadBatteryDetails,
                        onClose: { closeBatteryDetails() }
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 16, y: 8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(10)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Health: \(healthTitle)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(healthSummaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Updated \(monitor.snapshot.updatedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showHealthDetails.toggle()
            } label: {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(borderColor.opacity(0.6), lineWidth: 0.9)
                    )
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(healthColor)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHealthDetails, arrowEdge: .top) {
                healthDetailsPopover
            }
            .help("Show health diagnostics")
        }
    }

    private var cardsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricCard(
                    title: "Macintosh HD",
                    subtitle: diskSubtitle,
                    value: diskValue + diskUsePercentText,
                    actionTitle: "Free Up",
                    action: {
                        model.open(section: .spaceLens, action: .runSpaceLensScan)
                    }
                )
                metricCard(
                    title: "Memory",
                    subtitle: "Pressure \(Int(monitor.snapshot.memoryPressurePercent))%",
                    value: memoryValue,
                    actionTitle: "Inspect",
                    action: {
                        model.open(section: .performance, action: .runPerformanceScan)
                    }
                )
            }
            HStack(spacing: 10) {
                batteryMetricCard
                metricCard(
                    title: "CPU",
                    subtitle: "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%",
                    value: "\(Int(monitor.snapshot.cpuLoadPercent))% load",
                    actionTitle: "Diagnose",
                    action: {
                        model.open(section: .performance, action: .runPerformanceScan)
                    }
                )
            }
        }
    }

    private var consumersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Consumers")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("Preview")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                Button("Open Performance") {
                    model.open(section: .performance, action: .runPerformanceScan)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if consumerRows.isEmpty {
                Text("Collecting process telemetry...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(consumerRows.prefix(4))) { row in
                        HStack(spacing: 8) {
                            Text(row.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("CPU \(row.cpuText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("MEM \(row.memoryText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("BAT \(row.batteryText)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button("Reduce CPU") {
                    pendingReliefAction = .cpu
                    showReliefConfirm = true
                }
                .disabled(cpuReliefCandidates.isEmpty)
                .controlSize(.small)
                .buttonStyle(.bordered)

                Button("Reduce Memory") {
                    pendingReliefAction = .memory
                    showReliefConfirm = true
                }
                .disabled(memoryReliefCandidates.isEmpty)
                .controlSize(.small)
                .buttonStyle(.bordered)

                Spacer()

                Button("Restore Priorities") {
                    model.restorePriorities()
                }
                .disabled(!model.canRestorePriorities)
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's Recommendation")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(recommendationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Spacer()
                Button(recommendationActionTitle) {
                    recommendationAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Open DRay") {
                model.openMain()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Smart Scan") {
                model.open(section: .smartCare, action: .runUnifiedScan)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Open Performance") {
                model.open(section: .performance, action: .runPerformanceScan)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 4)

            Menu {
                Button(model.launchAtLoginEnabled ? "Start at Login: On" : "Start at Login: Off") {
                    model.toggleLaunchAtLogin()
                }
                Button("Restore Priorities") {
                    model.restorePriorities()
                }
                .disabled(!model.canRestorePriorities)
                Divider()
                Button("Quit Completely", role: .destructive) {
                    model.quitCompletely()
                }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private var healthDetailsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health details")
                .font(.headline)
            ForEach(healthIssues) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: issue.severity.icon)
                        .foregroundStyle(issue.severity.color)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.title)
                            .font(.subheadline.weight(.semibold))
                        Text(issue.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }
            HStack {
                Spacer()
                Button("Open Performance") {
                    model.open(section: .performance, action: .runPerformanceScan)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    private func metricCard(
        title: String,
        subtitle: String,
        value: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            HStack {
                Spacer()
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var batteryMetricCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Battery")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            Text(batteryStateText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(batteryValueText)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack {
                if let health = batterySnapshot?.healthPercent {
                    Text("Health \(health)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(health >= 80 ? .green : .orange)
                } else {
                    Text("Tap Details for diagnostics")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Details") {
                    openBatteryDetails()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var shellBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.42),
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if colorScheme == .light {
                RadialGradient(
                    colors: [Color.cyan.opacity(0.10), .clear],
                    center: .bottomLeading,
                    startRadius: 24,
                    endRadius: 280
                )
            }
            LinearGradient(
                colors: [
                    tintColor.opacity(colorScheme == .dark ? 0.24 : 0.15),
                    Color.clear,
                    tintColor.opacity(colorScheme == .dark ? 0.12 : 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.indigo.opacity(colorScheme == .dark ? 0.20 : 0.10), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 320
            )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.26),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor.opacity(colorScheme == .dark ? 0.78 : 0.45), lineWidth: 0.65)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.08), radius: 10, y: 5)
            .shadow(color: .white.opacity(colorScheme == .dark ? 0.0 : 0.26), radius: 5, x: -1, y: -1)
    }

    private var tintColor: Color {
        colorScheme == .dark ? Color.cyan : Color.blue
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.72)
    }

    private var healthSummaryLine: String {
        let alerts = healthIssues.filter { $0.severity != .info }
        if alerts.isEmpty {
            return "Macintosh HD · no critical issues"
        }
        return "Macintosh HD · \(alerts.count) alert(s)"
    }

    private var healthIssues: [HealthIssue] {
        var issues: [HealthIssue] = []

        if monitor.snapshot.memoryPressurePercent >= 88 {
            issues.append(.init(title: "Memory pressure is high", details: "Current pressure is \(Int(monitor.snapshot.memoryPressurePercent))%.", severity: .critical))
        } else if monitor.snapshot.memoryPressurePercent >= 72 {
            issues.append(.init(title: "Memory pressure is elevated", details: "Current pressure is \(Int(monitor.snapshot.memoryPressurePercent))%.", severity: .warning))
        }

        if monitor.snapshot.cpuLoadPercent >= 85 {
            issues.append(.init(title: "CPU load is very high", details: "Current CPU load is \(Int(monitor.snapshot.cpuLoadPercent))%.", severity: .critical))
        } else if monitor.snapshot.cpuLoadPercent >= 65 {
            issues.append(.init(title: "CPU load is elevated", details: "Current CPU load is \(Int(monitor.snapshot.cpuLoadPercent))%.", severity: .warning))
        }

        if let battery = monitor.snapshot.batteryLevelPercent, !(monitor.snapshot.batteryIsCharging ?? false) {
            if battery <= 15 {
                issues.append(.init(title: "Battery is low", details: "Battery level is \(battery)% and Mac is not charging.", severity: .critical))
            } else if battery <= 30 {
                issues.append(.init(title: "Battery is moderate", details: "Battery level is \(battery)% and Mac is not charging.", severity: .warning))
            }
        }

        if diskFreeRatio > 0, diskFreeRatio < 0.10 {
            issues.append(.init(title: "Low free disk space", details: "Only \(Int(diskFreeRatio * 100))% disk space is free.", severity: .critical))
        } else if diskFreeRatio > 0, diskFreeRatio < 0.18 {
            issues.append(.init(title: "Disk space is getting low", details: "Free disk space is \(Int(diskFreeRatio * 100))%.", severity: .warning))
        }

        if issues.isEmpty {
            issues.append(.init(title: "System looks healthy", details: "No major performance or storage alerts right now.", severity: .info))
        }
        return issues
    }

    private var recommendationText: String {
        if let critical = healthIssues.first(where: { $0.severity == .critical }) {
            return critical.details
        }
        if let warning = healthIssues.first(where: { $0.severity == .warning }) {
            return warning.details
        }
        return "Run Smart Scan to refresh diagnostics and cleanup opportunities."
    }

    private var recommendationActionTitle: String {
        healthIssues.contains(where: { $0.severity == .critical || $0.severity == .warning }) ? "Open Performance" : "Run Smart Scan"
    }

    private func recommendationAction() {
        if healthIssues.contains(where: { $0.severity == .critical || $0.severity == .warning }) {
            model.open(section: .performance, action: .runPerformanceScan)
            return
        }
        model.open(section: .smartCare, action: .runUnifiedScan)
    }

    private var memoryValue: String {
        let used = ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory)
        let total = ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryTotalBytes, countStyle: .memory)
        return "\(used) of \(total)"
    }

    private var diskSubtitle: String {
        let free = monitor.snapshot.diskFreeBytes
        if free > 0 {
            return "Available \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))"
        }
        return "Storage details unavailable"
    }

    private var diskValue: String {
        let total = monitor.snapshot.diskTotalBytes
        if total > 0 {
            return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
        return "n/a"
    }

    private var diskUsePercentText: String {
        let total = monitor.snapshot.diskTotalBytes
        let free = monitor.snapshot.diskFreeBytes
        guard total > 0 else { return "" }
        let used = max(0, total - free)
        let percent = Int((Double(used) / Double(total)) * 100)
        return " · \(percent)% used"
    }

    private var diskFreeRatio: Double {
        let total = monitor.snapshot.diskTotalBytes
        guard total > 0 else { return 0 }
        return Double(monitor.snapshot.diskFreeBytes) / Double(total)
    }

    private var batteryStateText: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return "Battery unavailable" }
        let charging = monitor.snapshot.batteryIsCharging ?? false
        let time = monitor.snapshot.batteryMinutesRemaining
        if let time {
            let h = time / 60
            let m = time % 60
            if charging {
                return "\(percent)% · charging (\(h)h \(m)m)"
            }
            return "\(percent)% · \(h)h \(m)m left"
        }
        return charging ? "\(percent)% · charging" : "\(percent)%"
    }

    private var batteryValueText: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return "n/a" }
        return "\(percent)%"
    }

    private var healthTitle: String {
        if healthIssues.contains(where: { $0.severity == .critical }) { return "Needs attention" }
        if healthIssues.contains(where: { $0.severity == .warning }) { return "Fair" }
        return "Good"
    }

    private var healthColor: Color {
        switch healthTitle {
        case "Good": return .green
        case "Fair": return .orange
        default: return .red
        }
    }

    private var consumerRows: [ConsumerRow] {
        var rows: [ConsumerRow] = []
        var seen = Set<String>()

        for cpu in monitor.snapshot.topCPUConsumers {
            let key = cpu.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let battery = monitor.snapshot.topBatteryConsumers.first { $0.name.caseInsensitiveCompare(cpu.name) == .orderedSame }
            rows.append(
                ConsumerRow(
                    id: cpu.name,
                    name: cpu.name,
                    cpuText: "\(Int(cpu.cpuPercent))%",
                    memoryText: "\(Int(cpu.memoryMB))MB",
                    batteryText: battery.map { String(format: "%.1f", $0.batteryImpactScore) } ?? String(format: "%.1f", cpu.batteryImpactScore)
                )
            )
            if rows.count >= 5 { break }
        }

        if rows.count < 5 {
            for memory in monitor.snapshot.topMemoryConsumers {
                let key = memory.name.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                let battery = monitor.snapshot.topBatteryConsumers.first { $0.name.caseInsensitiveCompare(memory.name) == .orderedSame }
                rows.append(
                    ConsumerRow(
                        id: memory.name,
                        name: memory.name,
                        cpuText: "\(Int(memory.cpuPercent))%",
                        memoryText: "\(Int(memory.memoryMB))MB",
                        batteryText: battery.map { String(format: "%.1f", $0.batteryImpactScore) } ?? String(format: "%.1f", memory.batteryImpactScore)
                    )
                )
                if rows.count >= 5 { break }
            }
        }
        return rows
    }

    private var cpuReliefCandidates: [ProcessConsumer] {
        let heavy = monitor.snapshot.topCPUConsumers.filter { $0.cpuPercent >= 18 }
        return heavy.isEmpty ? Array(monitor.snapshot.topCPUConsumers.prefix(3)) : heavy
    }

    private var memoryReliefCandidates: [ProcessConsumer] {
        let heavy = monitor.snapshot.topMemoryConsumers.filter { $0.memoryMB >= 700 }
        return heavy.isEmpty ? Array(monitor.snapshot.topMemoryConsumers.prefix(3)) : heavy
    }

    private var reliefDialogTitle: String {
        switch pendingReliefAction {
        case .cpu:
            return "Reduce CPU load by deprioritizing heavy apps?"
        case .memory:
            return "Reduce memory pressure by deprioritizing heavy apps?"
        case .none:
            return "Reduce load?"
        }
    }

    private var reliefActionTitle: String {
        switch pendingReliefAction {
        case .cpu: return "Lower Priority for Top CPU Apps"
        case .memory: return "Lower Priority for Top Memory Apps"
        case .none: return "Run"
        }
    }

    private func executeReliefAction() {
        guard let action = pendingReliefAction else { return }
        pendingReliefAction = nil
        showReliefConfirm = false
        switch action {
        case .cpu:
            model.reduceCPU(consumers: cpuReliefCandidates, limit: 3)
        case .memory:
            model.reduceMemory(consumers: memoryReliefCandidates, limit: 3)
        }
    }

    private var reliefConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.30 : 0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    pendingReliefAction = nil
                    showReliefConfirm = false
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Load Reduction")
                    .font(.headline)
                Text(reliefDialogTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        pendingReliefAction = nil
                        showReliefConfirm = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(reliefActionTitle) {
                        executeReliefAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .frame(width: 360, alignment: .leading)
            .background(cardBackground)
        }
    }

    private func reliefResultBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Load Reduction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("OK") {
                    model.reliefResultMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func openBatteryDetails() {
        guard !showBatteryDetails else { return }
        let now = Date()
        if now < suppressBatteryDetailsOpenUntil {
            return
        }

        showBatteryDetails = true
        loadBatteryDetails()
    }

    private func closeBatteryDetails() {
        guard showBatteryDetails else { return }
        suppressBatteryDetailsOpenUntil = Date().addingTimeInterval(0.8)
        showBatteryDetails = false
    }

    private func loadBatteryDetails() {
        guard !isBatteryDetailsLoading else { return }
        isBatteryDetailsLoading = true
        batteryDetailsError = nil
        Task(priority: .userInitiated) {
            let snapshot = model.fetchBatteryDetails()
            await MainActor.run {
                self.batterySnapshot = snapshot
                self.isBatteryDetailsLoading = false
                if snapshot.currentCapacityMAh == nil && snapshot.chargePercent == nil {
                    self.batteryDetailsError = "Battery details are unavailable on this Mac."
                }
            }
        }
    }
}

extension Notification.Name {
    static let helperDismissTransientUI = Notification.Name("dray.helper.dismiss.transient.ui")
}

private struct HealthIssue: Identifiable {
    let id = UUID()
    let title: String
    let details: String
    let severity: HealthIssueSeverity
}

private struct ConsumerRow: Identifiable {
    let id: String
    let name: String
    let cpuText: String
    let memoryText: String
    let batteryText: String
}

private enum ReliefAction {
    case cpu
    case memory
}

private enum HealthIssueSeverity {
    case info
    case warning
    case critical

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

private struct BatteryDetailsSheetView: View {
    let snapshot: BatteryDiagnosticsSnapshot?
    let isLoading: Bool
    let errorText: String?
    let onRefresh: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Battery Details")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Refresh") { onRefresh() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Close") { onClose() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.deviceName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        Text("Identifier: \(snapshot.machineIdentifier)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    BatteryProgressCard(
                        title: "Battery Charge",
                        valueText: formattedMAh(snapshot.currentCapacityMAh),
                        percentText: percentString(snapshot.chargePercent),
                        percentValue: normalizedPercent(snapshot.chargePercent),
                        tint: .green
                    )

                    BatteryProgressCard(
                        title: "Battery Health",
                        valueText: formattedMAh(snapshot.fullChargeCapacityMAh),
                        percentText: percentString(snapshot.healthPercent),
                        percentValue: normalizedPercent(snapshot.healthPercent),
                        tint: (snapshot.healthPercent ?? 0) >= 80 ? .green : .orange
                    )

                    primaryDurationCard(snapshot)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .leading),
                            GridItem(.flexible(), spacing: 10, alignment: .leading)
                        ],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(secondaryDetails(snapshot), id: \.0) { row in
                            detailMetricCell(title: row.0, value: row.1)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else if isLoading {
                VStack(spacing: 10) {
                    ProgressView("Loading battery diagnostics...")
                    Text("Reading AppleSmartBattery telemetry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorText ?? "No battery diagnostics available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") { onRefresh() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(12)
        .frame(width: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.9)
        )
    }

    private func detailMetricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryDurationCard(_ snapshot: BatteryDiagnosticsSnapshot) -> some View {
        let row = primaryDurationRow(snapshot)
        return VStack(spacing: 4) {
            Text(row.0)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(row.1)
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func secondaryDetails(_ snapshot: BatteryDiagnosticsSnapshot) -> [(String, String)] {
        [
            ("Power", formattedPower(snapshot.powerWatts)),
            ("Temperature", formattedTemperature(snapshot.temperatureCelsius)),
            ("Charge Cycles", formattedInt(snapshot.cycleCount)),
            ("Voltage", formattedVoltage(snapshot.voltageVolts)),
            ("Amperage", formattedAmperage(snapshot.amperageAmps)),
            ("Updated", snapshot.updatedAt.formatted(date: .omitted, time: .shortened))
        ]
    }

    private func primaryDurationRow(_ snapshot: BatteryDiagnosticsSnapshot) -> (String, String) {
        if snapshot.isCharging == true {
            return ("Time to Full", formattedDuration(snapshot.minutesToFull))
        }
        if snapshot.isCharging == false {
            return ("Time to Empty", formattedDuration(snapshot.minutesToEmpty))
        }
        if snapshot.minutesToFull != nil {
            return ("Time to Full", formattedDuration(snapshot.minutesToFull))
        }
        if snapshot.minutesToEmpty != nil {
            return ("Time to Empty", formattedDuration(snapshot.minutesToEmpty))
        }
        return ("Time", "n/a")
    }

    private func formattedInt(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)"
    }

    private func formattedMAh(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value.formatted(.number.grouping(.automatic))) mAh"
    }

    private func formattedTemperature(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f °C", value)
    }

    private func formattedVoltage(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f V", value)
    }

    private func formattedAmperage(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f A", value)
    }

    private func formattedPower(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        if value < 0 {
            return String(format: "Discharging %.1f W", abs(value))
        }
        if value > 0 {
            return String(format: "Charging %.1f W", value)
        }
        return "0 W"
    }

    private func percentString(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)%"
    }

    private func formattedDuration(_ minutes: Int?) -> String {
        guard let minutes, minutes >= 0 else { return "n/a" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func normalizedPercent(_ value: Int?) -> Double {
        guard let value else { return 0 }
        return min(1, max(0, Double(value) / 100.0))
    }

}

private struct BatteryProgressCard: View {
    let title: String
    let valueText: String
    let percentText: String
    let percentValue: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.16))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.88), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, proxy.size.width * percentValue))
                    Text(percentText)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: 18)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
