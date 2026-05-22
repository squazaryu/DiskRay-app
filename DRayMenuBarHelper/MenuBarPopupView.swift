import SwiftUI
import AppKit

struct MenuBarPopupView: View {
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
    @State private var batteryAutoRefreshTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            healthHeroCard
            metricTilesGrid
            consumersSection
            recommendationCard
            quickActionsSection
            footerTelemetrySection
        }
        .padding(10)
        .background(shellBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(width: 430)
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
            stopBatteryAutoRefresh()
        }
        .onChange(of: showBatteryDetails) {
            if showBatteryDetails {
                startBatteryAutoRefresh()
            } else {
                stopBatteryAutoRefresh()
            }
            if !showBatteryDetails {
                suppressBatteryDetailsOpenUntil = Date().addingTimeInterval(0.45)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = model.reliefResultMessage {
                ReliefResultBannerView(
                    message: message,
                    colorScheme: colorScheme
                ) {
                    model.reliefResultMessage = nil
                }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if showReliefConfirm {
                ReliefConfirmOverlayView(
                    colorScheme: colorScheme,
                    title: "Load Reduction",
                    message: reliefDialogTitle,
                    actionTitle: reliefActionTitle,
                    onCancel: {
                        pendingReliefAction = nil
                        showReliefConfirm = false
                    },
                    onConfirm: { executeReliefAction() }
                )
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
                        onRefresh: { loadBatteryDetails(force: true) },
                        onClose: { closeBatteryDetails() }
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 16, y: 8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(10)
            }
        }
    }

    private var healthHeroCard: some View {
        HStack(spacing: 14) {
            Button {
                showHealthDetails.toggle()
            } label: {
                MenuBarMiniRing(
                    icon: healthTitle == "Good" ? "checkmark" : "exclamationmark",
                    tint: healthColor,
                    size: 68,
                    progress: healthRingProgress
                )
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .popover(isPresented: $showHealthDetails, arrowEdge: .top) {
                MenuBarHealthDetailsPopoverView(
                    issues: healthIssues,
                    onOpenPerformance: {
                        model.open(section: .performance, action: .runPerformanceScan)
                    }
                )
            }
            .help("Health Details")

            VStack(alignment: .leading, spacing: 4) {
                Text("Mac Health")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(healthTitle)
                    .font(.system(size: 24, weight: .semibold))
                Text(healthSummaryLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(healthHeroBatteryLine)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(healthHeroBatteryTint)
                Text("Last checked: \(monitor.snapshot.updatedAt, style: .time)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                model.open(section: .smartCare, action: .runUnifiedScan)
            } label: {
                Label("Smart Scan", systemImage: "wand.and.sparkles")
                    .frame(minWidth: 94)
            }
            .buttonStyle(MenuBarSoftButtonStyle(tone: .primary))
            .controlSize(.small)
        }
        .padding(12)
        .background(cardBackground(accent: .accentColor, cornerRadius: 16))
    }

    private var metricTilesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            MenuBarMetricTileCard(
                title: "Storage",
                value: diskUsedValue,
                subtitle: diskUsePercentText.replacingOccurrences(of: " · ", with: ""),
                icon: "internaldrive",
                tint: calmStorageTint,
                actionTitle: "Free Up"
            ) {
                model.open(section: .spaceLens, action: .runSpaceLensScan)
            }

            MenuBarMetricTileCard(
                title: "Memory",
                value: memoryValue,
                subtitle: "Pressure \(Int(monitor.snapshot.memoryPressurePercent))%",
                icon: "memorychip",
                tint: calmMemoryTint,
                actionTitle: "Inspect"
            ) {
                model.open(section: .performance, action: .runPerformanceScan)
            }

            MenuBarMetricTileCard(
                title: "Battery",
                value: batteryValueText,
                subtitle: batteryStateText,
                icon: "battery.75percent",
                tint: calmBatteryTint,
                actionTitle: "Details"
            ) {
                openBatteryDetails()
            }

            MenuBarMetricTileCard(
                title: "CPU",
                value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                subtitle: "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%",
                icon: "waveform.path.ecg",
                tint: calmCPUTint,
                actionTitle: "Diagnose"
            ) {
                model.open(section: .performance, action: .runPerformanceScan)
            }
        }
    }

    private var consumersSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Top Consumers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button("Performance") {
                    model.open(section: .performance, action: .runPerformanceScan)
                }
                .buttonStyle(MenuBarSoftButtonStyle())
                .controlSize(.small)
            }
            if monitor.snapshot.topCPUConsumers.isEmpty {
                Text("Collecting process telemetry...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(monitor.snapshot.topCPUConsumers.prefix(3))) { consumer in
                        MenuBarRankedConsumerRow(
                            name: consumer.name,
                            detail: "MEM \(Int(consumer.memoryMB))MB · EI \(String(format: "%.1f", consumer.batteryImpactScore))",
                            value: "\(Int(consumer.cpuPercent))%",
                            progress: min(1, consumer.cpuPercent / maxTopCPU),
                            tint: calmDiagnosticTint
                        )
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
                .buttonStyle(MenuBarSoftButtonStyle())

                Button("Reduce Memory") {
                    pendingReliefAction = .memory
                    showReliefConfirm = true
                }
                .disabled(memoryReliefCandidates.isEmpty)
                .controlSize(.small)
                .buttonStyle(MenuBarSoftButtonStyle())

                Spacer()

                Button("Restore Priorities") {
                    model.restorePriorities()
                }
                .disabled(!model.canRestorePriorities)
                .controlSize(.small)
                .buttonStyle(MenuBarSoftButtonStyle())
            }
        }
        .padding(10)
        .background(cardBackground(accent: .accentColor, cornerRadius: 16))
    }

    private var recommendationCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recommendation")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(recommendationText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(recommendationActionTitle) {
                recommendationAction()
            }
            .buttonStyle(MenuBarSoftButtonStyle())
            .controlSize(.small)
        }
        .padding(9)
        .background(cardBackground(accent: .gray, cornerRadius: 14))
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Quick Actions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button("Smart Scan") {
                    model.open(section: .smartCare, action: .runUnifiedScan)
                }
                .buttonStyle(MenuBarSoftButtonStyle())
                .controlSize(.small)

                Button("Open DRay") {
                    model.openMain()
                }
                .buttonStyle(MenuBarSoftButtonStyle())
                .controlSize(.small)

                Button("Quit Completely") {
                    model.quitCompletely()
                }
                .buttonStyle(MenuBarSoftButtonStyle(tone: .danger))
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
                    Button("Performance") {
                        model.open(section: .performance, action: .runPerformanceScan)
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .font(popupButtonFont)
                }
                .controlSize(.small)
                .buttonStyle(MenuBarSoftButtonStyle())
            }
        }
        .padding(9)
        .background(cardBackground(accent: .gray, cornerRadius: 14))
    }

    private var footerTelemetrySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Telemetry")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Updated \(monitor.snapshot.updatedAt, style: .time)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                telemetryPill(
                    title: "Uptime",
                    value: formattedUptime(monitor.snapshot.uptimeSeconds),
                    tint: calmTelemetryTint
                )
                telemetryPill(
                    title: "Down",
                    value: formattedTransferRate(monitor.snapshot.networkDownBytesPerSecond),
                    tint: calmTelemetryTint
                )
                telemetryPill(
                    title: "Up",
                    value: formattedTransferRate(monitor.snapshot.networkUpBytesPerSecond),
                    tint: calmTelemetryTint
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(cardBackground(accent: .gray, cornerRadius: 12))
    }

    private var popupButtonFont: Font {
        .system(size: 12, weight: .semibold)
    }

    private var calmStorageTint: Color {
        Color(red: 0.38, green: 0.46, blue: 0.50)
    }

    private var calmMemoryTint: Color {
        Color(red: 0.45, green: 0.42, blue: 0.50)
    }

    private var calmBatteryTint: Color {
        Color(red: 0.34, green: 0.50, blue: 0.40)
    }

    private var calmCPUTint: Color {
        Color(red: 0.58, green: 0.42, blue: 0.30)
    }

    private var calmDiagnosticTint: Color {
        Color(red: 0.48, green: 0.52, blue: 0.54)
    }

    private var calmTelemetryTint: Color {
        Color.secondary
    }

    private var shellBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(shellNeutralFill)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.050 : 0.065),
                            Color.white.opacity(colorScheme == .dark ? 0.010 : 0.025),
                            Color.black.opacity(colorScheme == .dark ? 0.055 : 0.018)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func cardBackground(accent: Color, cornerRadius: CGFloat = 10) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardNeutralFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.020 : 0.050),
                                accent.opacity(colorScheme == .dark ? 0.014 : 0.008),
                                Color.white.opacity(colorScheme == .dark ? 0.004 : 0.016),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.070 : 0.050), lineWidth: 0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.black.opacity(0.08) : Color.white.opacity(0.10), lineWidth: 0.35)
            )
    }

    private var shellNeutralFill: Color {
        colorScheme == .dark
        ? Color(red: 0.095, green: 0.100, blue: 0.115).opacity(0.92)
        : Color(red: 0.925, green: 0.935, blue: 0.955).opacity(0.90)
    }

    private var cardNeutralFill: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.046)
        : Color.white.opacity(0.46)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.085) : Color.primary.opacity(0.050)
    }

    private func telemetryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(MenuBarCompactRowSurface(colorScheme: colorScheme, accent: tint, cornerRadius: 10))
    }

    private func formattedUptime(_ uptimeSeconds: TimeInterval) -> String {
        let uptime = max(0, Int(uptimeSeconds))
        let days = uptime / 86_400
        let hours = (uptime % 86_400) / 3_600
        let minutes = (uptime % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    private func formattedTransferRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 1 else { return "0 KB/s" }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .binary)
        return "\(formatted)/s"
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

    private var diskUsedValue: String {
        let total = monitor.snapshot.diskTotalBytes
        let free = monitor.snapshot.diskFreeBytes
        guard total > 0 else { return "n/a" }
        return ByteCountFormatter.string(fromByteCount: max(0, total - free), countStyle: .file)
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

    private var healthHeroBatteryLine: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return "Battery: n/a" }
        if monitor.snapshot.batteryIsCharging == true {
            return "Battery: \(percent)% (charging)"
        }
        return "Battery: \(percent)%"
    }

    private var healthHeroBatteryTint: Color {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return .secondary }
        if percent < 20, monitor.snapshot.batteryIsCharging != true {
            return Color(red: 0.78, green: 0.24, blue: 0.22)
        }
        return .secondary
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

    private var healthRingProgress: Double {
        switch healthTitle {
        case "Good":
            return 0.98
        case "Fair":
            return 0.62
        default:
            return 0.32
        }
    }

    private var maxTopCPU: Double {
        max(monitor.snapshot.topCPUConsumers.prefix(3).map(\.cpuPercent).max() ?? 100, 100)
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

    private func openBatteryDetails() {
        guard !showBatteryDetails else { return }
        let now = Date()
        if now < suppressBatteryDetailsOpenUntil {
            return
        }

        showBatteryDetails = true
        loadBatteryDetails(force: false)
    }

    private func closeBatteryDetails() {
        guard showBatteryDetails else { return }
        suppressBatteryDetailsOpenUntil = Date().addingTimeInterval(0.8)
        showBatteryDetails = false
    }

    private func loadBatteryDetails(force: Bool) {
        guard !isBatteryDetailsLoading else { return }
        isBatteryDetailsLoading = true
        batteryDetailsError = nil
        Task(priority: .userInitiated) {
            let snapshot = model.fetchBatteryDetails(force: force)
            await MainActor.run {
                self.batterySnapshot = snapshot
                self.isBatteryDetailsLoading = false
                if snapshot.currentCapacityMAh == nil && snapshot.chargePercent == nil {
                    self.batteryDetailsError = "Battery details are unavailable on this Mac."
                }
            }
        }
    }

    private func startBatteryAutoRefresh() {
        stopBatteryAutoRefresh()
        guard showBatteryDetails else { return }

        batteryAutoRefreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                guard showBatteryDetails else { return }
                loadBatteryDetails(force: false)
            }
        }
    }

    private func stopBatteryAutoRefresh() {
        batteryAutoRefreshTask?.cancel()
        batteryAutoRefreshTask = nil
    }

}

extension Notification.Name {
    static let helperDismissTransientUI = Notification.Name("dray.helper.dismiss.transient.ui")
}
