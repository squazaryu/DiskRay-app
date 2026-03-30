import SwiftUI
import AppKit

struct MenuBarPopupView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var monitor = LiveSystemMetricsMonitor()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showHealthDetails = false
    @State private var showBatteryDetails = false
    @State private var batterySnapshot: BatteryDiagnosticsSnapshot?
    @State private var isBatteryDetailsLoading = false
    @State private var batteryDetailsError: String?
    @State private var pendingReliefAction: ReliefAction?
    @State private var showReliefConfirm = false
    @State private var reliefResultMessage: String?
    private let batteryService = BatteryDiagnosticsService()

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
        .frame(width: 452)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .sheet(isPresented: $showBatteryDetails) {
            BatteryDetailsSheetView(
                snapshot: batterySnapshot,
                isLoading: isBatteryDetailsLoading,
                errorText: batteryDetailsError,
                onRefresh: loadBatteryDetails
            )
        }
        .confirmationDialog(
            reliefDialogTitle,
            isPresented: $showReliefConfirm,
            titleVisibility: .visible
        ) {
            Button(reliefActionTitle, role: .destructive) {
                executeReliefAction()
            }
            Button("Cancel", role: .cancel) {
                pendingReliefAction = nil
            }
        }
        .alert("Load Reduction", isPresented: Binding(
            get: { reliefResultMessage != nil },
            set: { if !$0 { reliefResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reliefResultMessage ?? "")
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
                        open(section: .spaceLens) {
                            model.scanSelected()
                        }
                    }
                )
                metricCard(
                    title: "Memory",
                    subtitle: "Pressure \(Int(monitor.snapshot.memoryPressurePercent))%",
                    value: memoryValue,
                    actionTitle: "Inspect",
                    action: {
                        open(section: .performance) {
                            model.runPerformanceScan()
                        }
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
                        open(section: .performance) {
                            model.runPerformanceScan()
                        }
                    }
                )
            }
            HStack(spacing: 10) {
                metricCard(
                    title: "Network",
                    subtitle: "↓ \(networkSpeedText(monitor.snapshot.networkDownBytesPerSecond)) · ↑ \(networkSpeedText(monitor.snapshot.networkUpBytesPerSecond))",
                    value: "\(Int(monitor.snapshot.uptimeSeconds / 3600))h uptime",
                    actionTitle: "Open",
                    action: { open(section: .smartCare) }
                )
                metricCard(
                    title: "My Clutter",
                    subtitle: "Duplicate groups",
                    value: "\(model.duplicateGroups.count)",
                    actionTitle: "Review",
                    action: {
                        open(section: .clutter) {
                            model.scanDuplicatesInHome()
                        }
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
            }
            if monitor.snapshot.topCPUConsumers.isEmpty && monitor.snapshot.topBatteryConsumers.isEmpty {
                Text("Collecting process telemetry...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(consumerRows) { row in
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
        }
        .padding(12)
        .background(cardBackground)
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Recommendation")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(recommendationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        HStack {
            Button("Smart Scan") {
                open(section: .smartCare) {
                    model.runUnifiedScan()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Open DRay") {
                open(section: .smartCare)
            }
            .controlSize(.small)

            Button("Quit Completely", role: .destructive) {
                AppTerminationCoordinator.shared.terminateCompletely()
            }
            .controlSize(.small)

            Spacer()

            if let url = model.lastExportedDiagnosticURL {
                Button("Reveal Report") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .controlSize(.small)
            }
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
                }
                .padding(8)
                .background(cardBackground)
            }
            HStack {
                Spacer()
                Button("Open Performance") {
                    open(section: .performance) {
                        model.runPerformanceScan()
                    }
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
                Button {
                    openBatteryDetails()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tintColor)
                }
                .buttonStyle(.plain)
                .help("Open battery details")
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
                    Text("Tap arrow for details")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Details") {
                    open(section: .performance)
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
                    .stroke(borderColor.opacity(0.85), lineWidth: 0.85)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 8, y: 4)
    }

    private var tintColor: Color {
        colorScheme == .dark ? Color.cyan : Color.blue
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)
    }

    private var healthSummaryLine: String {
        let alerts = healthIssues.filter { $0.severity != .info }
        if alerts.isEmpty {
            return "\(model.selectedTarget.name) · no critical issues"
        }
        return "\(model.selectedTarget.name) · \(alerts.count) alert(s)"
    }

    private var healthIssues: [HealthIssue] {
        var issues: [HealthIssue] = []

        if monitor.snapshot.memoryPressurePercent >= 88 {
            issues.append(HealthIssue(
                title: "Memory pressure is high",
                details: "Current pressure is \(Int(monitor.snapshot.memoryPressurePercent))%. Close heavy apps or run performance diagnostics.",
                severity: .critical
            ))
        } else if monitor.snapshot.memoryPressurePercent >= 72 {
            issues.append(HealthIssue(
                title: "Memory pressure is elevated",
                details: "Current pressure is \(Int(monitor.snapshot.memoryPressurePercent))%.",
                severity: .warning
            ))
        }

        if monitor.snapshot.cpuLoadPercent >= 85 {
            issues.append(HealthIssue(
                title: "CPU load is very high",
                details: "Current CPU load is \(Int(monitor.snapshot.cpuLoadPercent))%.",
                severity: .critical
            ))
        } else if monitor.snapshot.cpuLoadPercent >= 65 {
            issues.append(HealthIssue(
                title: "CPU load is elevated",
                details: "Current CPU load is \(Int(monitor.snapshot.cpuLoadPercent))%.",
                severity: .warning
            ))
        }

        if let battery = monitor.snapshot.batteryLevelPercent, !(monitor.snapshot.batteryIsCharging ?? false) {
            if battery <= 15 {
                issues.append(HealthIssue(
                    title: "Battery is low",
                    details: "Battery level is \(battery)% and Mac is not charging.",
                    severity: .critical
                ))
            } else if battery <= 30 {
                issues.append(HealthIssue(
                    title: "Battery is moderate",
                    details: "Battery level is \(battery)% and Mac is not charging.",
                    severity: .warning
                ))
            }
        }

        let freeRatio = diskFreeRatio
        if freeRatio > 0, freeRatio < 0.10 {
            issues.append(HealthIssue(
                title: "Low free disk space",
                details: "Only \(Int(freeRatio * 100))% disk space is free.",
                severity: .critical
            ))
        } else if freeRatio > 0, freeRatio < 0.18 {
            issues.append(HealthIssue(
                title: "Disk space is getting low",
                details: "Free disk space is \(Int(freeRatio * 100))%.",
                severity: .warning
            ))
        }

        let startupCount = model.performanceReport?.startupEntries.count ?? 0
        if startupCount > 24 {
            issues.append(HealthIssue(
                title: "Many startup entries",
                details: "\(startupCount) startup items detected. Consider disabling non-essential ones.",
                severity: .warning
            ))
        }

        if model.duplicateGroups.count > 0 {
            issues.append(HealthIssue(
                title: "Duplicate files detected",
                details: "\(model.duplicateGroups.count) duplicate groups can be reviewed in My Clutter.",
                severity: .info
            ))
        }

        if issues.isEmpty {
            issues.append(HealthIssue(
                title: "System looks healthy",
                details: "No major performance or storage alerts right now.",
                severity: .info
            ))
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
        return "Run Smart Scan to refresh diagnostics and keep cleanup recommendations up to date."
    }

    private var recommendationActionTitle: String {
        if healthIssues.contains(where: { $0.severity == .critical || $0.severity == .warning }) {
            return "Open Performance"
        }
        if model.duplicateGroups.count > 0 { return "Review Duplicates" }
        return "Run Smart Scan"
    }

    private func recommendationAction() {
        if healthIssues.contains(where: { $0.severity == .critical || $0.severity == .warning }) {
            open(section: .performance) {
                model.runPerformanceScan()
            }
            return
        }
        if model.duplicateGroups.count > 0 {
            open(section: .clutter) {
                model.scanDuplicatesInHome()
            }
            return
        }
        open(section: .smartCare) {
            model.runUnifiedScan()
        }
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

    private func networkSpeedText(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
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
        if healthIssues.contains(where: { $0.severity == .critical }) {
            return "Needs attention"
        }
        if healthIssues.contains(where: { $0.severity == .warning }) {
            return "Fair"
        }
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

        if rows.count < 5 {
            for battery in monitor.snapshot.topBatteryConsumers {
                let key = battery.name.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                rows.append(
                    ConsumerRow(
                        id: battery.name,
                        name: battery.name,
                        cpuText: "\(Int(battery.cpuPercent))%",
                        memoryText: "\(Int(battery.memoryMB))MB",
                        batteryText: String(format: "%.1f", battery.batteryImpactScore)
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
            return "Reduce CPU load by closing heavy apps?"
        case .memory:
            return "Reduce memory load by closing heavy apps?"
        case .none:
            return "Reduce load?"
        }
    }

    private var reliefActionTitle: String {
        switch pendingReliefAction {
        case .cpu: return "Close Top CPU Apps"
        case .memory: return "Close Top Memory Apps"
        case .none: return "Run"
        }
    }

    private func executeReliefAction() {
        guard let action = pendingReliefAction else { return }
        let result: LoadReliefResult
        switch action {
        case .cpu:
            result = model.reduceCPULoad(consumers: cpuReliefCandidates, limit: 3)
        case .memory:
            result = model.reduceMemoryLoad(consumers: memoryReliefCandidates, limit: 3)
        }
        pendingReliefAction = nil
        open(section: .performance) {
            model.runPerformanceScan()
        }

        let terminatedText = result.terminated.isEmpty ? "0" : "\(result.terminated.count): " + result.terminated.joined(separator: ", ")
        let failedText = result.failed.isEmpty ? "0" : "\(result.failed.count): " + result.failed.joined(separator: ", ")
        let skippedText = result.skipped.isEmpty ? "0" : "\(result.skipped.count): " + result.skipped.joined(separator: ", ")
        reliefResultMessage = "Terminated \(terminatedText)\nFailed \(failedText)\nSkipped \(skippedText)"
    }

    private func openBatteryDetails() {
        showBatteryDetails = true
        loadBatteryDetails()
    }

    private func loadBatteryDetails() {
        guard !isBatteryDetailsLoading else { return }
        isBatteryDetailsLoading = true
        batteryDetailsError = nil
        Task(priority: .userInitiated) {
            let snapshot = batteryService.fetchSnapshot()
            await MainActor.run {
                self.batterySnapshot = snapshot
                self.isBatteryDetailsLoading = false
                if snapshot.currentCapacityMAh == nil && snapshot.chargePercent == nil {
                    self.batteryDetailsError = "Battery details are unavailable on this Mac."
                }
            }
        }
    }

    private func open(section: AppSection, action: (() -> Void)? = nil) {
        action?()
        model.openSection(section)
    }
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Battery Details")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("Refresh") { onRefresh() }
                    .buttonStyle(.bordered)
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }

            if let snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.deviceName)
                                .font(.headline)
                            Text("Identifier: \(snapshot.machineIdentifier)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
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

                        VStack(spacing: 8) {
                            detailRow("Full Charge Capacity", formattedMAh(snapshot.fullChargeCapacityMAh))
                            detailRow("Design Capacity", formattedMAh(snapshot.designCapacityMAh))
                            detailRow("Charge Cycles", formattedInt(snapshot.cycleCount))
                            detailRow("Design Cycles", formattedInt(snapshot.designCycleCount))
                            detailRow("Battery Temperature", formattedTemperature(snapshot.temperatureCelsius))
                            detailRow("Voltage", formattedVoltage(snapshot.voltageVolts))
                            detailRow("Amperage", formattedAmperage(snapshot.amperageAmps))
                            detailRow("Power", formattedPower(snapshot.powerWatts))
                            detailRow("Adapter", formattedAdapter(snapshot.adapterWatts))
                            detailRow("Status", chargingText(snapshot))
                            detailRow("Low Power Mode", snapshot.lowPowerModeEnabled ? "Enabled" : "Disabled")
                            detailRow("Manufacture Date", snapshot.manufactureDate ?? "n/a")
                            detailRow("Updated", snapshot.updatedAt.formatted(date: .abbreviated, time: .standard))
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.vertical, 2)
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
        .padding(16)
        .frame(width: 460, height: 610)
        .background(.ultraThinMaterial)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
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

    private func formattedAdapter(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.0f W", value)
    }

    private func percentString(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)%"
    }

    private func normalizedPercent(_ value: Int?) -> Double {
        guard let value else { return 0 }
        return min(1, max(0, Double(value) / 100.0))
    }

    private func chargingText(_ snapshot: BatteryDiagnosticsSnapshot) -> String {
        if snapshot.isCharging == true {
            if let minutes = snapshot.minutesRemaining {
                return "Charging (\(minutes / 60)h \(minutes % 60)m)"
            }
            return "Charging"
        }
        if let minutes = snapshot.minutesRemaining {
            return "\(minutes / 60)h \(minutes % 60)m remaining"
        }
        return "On battery"
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
                    .font(.headline)
                Spacer()
                Text(valueText)
                    .font(.headline.weight(.semibold))
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
            .frame(height: 22)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
