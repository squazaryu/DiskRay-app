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
