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
    @State private var cpuTrend: [Double] = []
    @State private var memoryTrend: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            popupHeader
            healthHeroCard
            metricTilesGrid
            consumersSection
            recommendationCard
            footer
        }
        .padding(10)
        .background(shellBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor.opacity(0.9), lineWidth: 1)
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
        .onReceive(monitor.$snapshot) { snapshot in
            appendTrend(snapshot.cpuLoadPercent, to: &cpuTrend)
            appendTrend(snapshot.memoryPressurePercent, to: &memoryTrend)
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

    private var popupHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DRay")
                    .font(.system(size: 20, weight: .semibold))
                Text("Updated \(monitor.snapshot.updatedAt, style: .time)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var healthHeroCard: some View {
        HStack(spacing: 14) {
            Button {
                showHealthDetails.toggle()
            } label: {
                MenuBarMiniRing(icon: healthTitle == "Good" ? "checkmark" : "exclamationmark", tint: healthColor, size: 68)
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
                Text("Last checked: \(monitor.snapshot.updatedAt, style: .time)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            Spacer(minLength: 8)

            Button {
                model.open(section: .smartCare, action: .runUnifiedScan)
            } label: {
                Label("Smart Scan", systemImage: "wand.and.sparkles")
                    .frame(minWidth: 94)
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(cardBackground(accent: .blue, cornerRadius: 16))
    }

    private var metricTilesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            MenuBarMetricTileCard(
                title: "Storage",
                value: diskUsedValue,
                subtitle: diskUsePercentText.replacingOccurrences(of: " · ", with: ""),
                icon: "internaldrive",
                tint: .blue,
                progress: diskUsedRatio,
                actionTitle: "Free Up"
            ) {
                model.open(section: .spaceLens, action: .runSpaceLensScan)
            }

            MenuBarMetricTileCard(
                title: "Memory",
                value: memoryValue,
                subtitle: "Pressure \(Int(monitor.snapshot.memoryPressurePercent))%",
                icon: "memorychip",
                tint: .purple,
                progress: min(1, monitor.snapshot.memoryPressurePercent / 100),
                sparkline: memoryTrend,
                actionTitle: "Inspect"
            ) {
                model.open(section: .performance, action: .runPerformanceScan)
            }

            MenuBarMetricTileCard(
                title: "Battery",
                value: batteryValueText,
                subtitle: batteryStateText,
                icon: "battery.75percent",
                tint: .green,
                progress: monitor.snapshot.batteryLevelPercent.map { Double($0) / 100.0 },
                actionTitle: "Details"
            ) {
                openBatteryDetails()
            }

            MenuBarMetricTileCard(
                title: "CPU",
                value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                subtitle: "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%",
                icon: "waveform.path.ecg",
                tint: .orange,
                progress: min(1, monitor.snapshot.cpuLoadPercent / 100),
                sparkline: cpuTrend,
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
                .font(popupButtonFont)
                .buttonStyle(.bordered)
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
                            tint: .blue
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
                .font(popupButtonFont)
                .controlSize(.small)
                .buttonStyle(.bordered)

                Button("Reduce Memory") {
                    pendingReliefAction = .memory
                    showReliefConfirm = true
                }
                .disabled(memoryReliefCandidates.isEmpty)
                .font(popupButtonFont)
                .controlSize(.small)
                .buttonStyle(.bordered)

                Spacer()

                Button("Restore Priorities") {
                    model.restorePriorities()
                }
                .disabled(!model.canRestorePriorities)
                .font(popupButtonFont)
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(cardBackground(accent: .blue, cornerRadius: 16))
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
            .font(popupButtonFont)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(9)
        .background(cardBackground(accent: .cyan, cornerRadius: 14))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button("Open DRay") {
                model.openMain()
            }
            .font(popupButtonFont)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Smart Scan") {
                model.open(section: .smartCare, action: .runUnifiedScan)
            }
            .font(popupButtonFont)
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Performance") {
                model.open(section: .performance, action: .runPerformanceScan)
            }
            .font(popupButtonFont)
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
                    .font(popupButtonFont)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private var popupButtonFont: Font {
        .system(size: 12, weight: .semibold)
    }

    private var shellBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.34),
                            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10),
                            Color.black.opacity(colorScheme == .dark ? 0.16 : 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RadialGradient(
                colors: [
                    Color.cyan.opacity(colorScheme == .dark ? 0.10 : 0.07),
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 260
            )
            RadialGradient(
                colors: [
                    Color.indigo.opacity(colorScheme == .dark ? 0.08 : 0.05),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 280
            )
        }
    }

    private func cardBackground(accent: Color, cornerRadius: CGFloat = 10) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.16 : 0.10),
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.28),
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.20) : Color.white.opacity(0.66), lineWidth: 0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.black.opacity(0.26) : Color.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.10), radius: 7, y: 3)
            .shadow(color: .white.opacity(colorScheme == .dark ? 0.0 : 0.18), radius: 3, x: -1, y: -1)
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

    private var diskUsedRatio: Double {
        let total = monitor.snapshot.diskTotalBytes
        let free = monitor.snapshot.diskFreeBytes
        guard total > 0 else { return 0 }
        return Double(max(0, total - free)) / Double(total)
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

    private func appendTrend(_ value: Double, to series: inout [Double], limit: Int = 28) {
        guard value.isFinite else { return }
        series.append(value)
        if series.count > limit {
            series.removeFirst(series.count - limit)
        }
    }
}

extension Notification.Name {
    static let helperDismissTransientUI = Notification.Name("dray.helper.dismiss.transient.ui")
}
