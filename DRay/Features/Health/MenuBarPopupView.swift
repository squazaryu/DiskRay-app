import SwiftUI
import AppKit

struct MenuBarPopupView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var monitor = LiveSystemMetricsMonitor()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showHealthDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            cardsGrid
            recommendationCard
            footer
        }
        .padding(12)
        .background(shellBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: 430)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Health: \(healthTitle)")
                    .font(.title3.weight(.bold))
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
                    .fill(healthColor.opacity(colorScheme == .dark ? 0.25 : 0.14))
                    .frame(width: 38, height: 38)
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
                    action: { model.scanSelected() }
                )
                metricCard(
                    title: "Memory",
                    subtitle: "Pressure \(Int(monitor.snapshot.memoryPressurePercent))%",
                    value: memoryValue,
                    actionTitle: "Open DRay",
                    action: { NSApp.activate(ignoringOtherApps: true) }
                )
            }
            HStack(spacing: 10) {
                metricCard(
                    title: "Battery",
                    subtitle: batteryStateText,
                    value: batteryValueText,
                    actionTitle: "Health",
                    action: { NSApp.activate(ignoringOtherApps: true) }
                )
                metricCard(
                    title: "CPU",
                    subtitle: "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%",
                    value: "\(Int(monitor.snapshot.cpuLoadPercent))% load",
                    actionTitle: "Diagnose",
                    action: { model.runPerformanceScan() }
                )
            }
            HStack(spacing: 10) {
                metricCard(
                    title: "Network",
                    subtitle: "↓ \(networkSpeedText(monitor.snapshot.networkDownBytesPerSecond)) · ↑ \(networkSpeedText(monitor.snapshot.networkUpBytesPerSecond))",
                    value: "\(Int(monitor.snapshot.uptimeSeconds / 3600))h uptime",
                    actionTitle: "Open DRay",
                    action: { NSApp.activate(ignoringOtherApps: true) }
                )
                metricCard(
                    title: "My Clutter",
                    subtitle: "Duplicate groups",
                    value: "\(model.duplicateGroups.count)",
                    actionTitle: "Scan",
                    action: { model.scanDuplicatesInHome() }
                )
            }
        }
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
                model.runUnifiedScan()
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Open DRay") {
                NSApp.activate(ignoringOtherApps: true)
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
                    model.runPerformanceScan()
                    NSApp.activate(ignoringOtherApps: true)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.semibold))
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var shellBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    tintColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor.opacity(0.7), lineWidth: 0.8)
            )
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
            model.runPerformanceScan()
            return
        }
        if model.duplicateGroups.count > 0 {
            model.scanDuplicatesInHome()
            return
        }
        model.runUnifiedScan()
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
}

private struct HealthIssue: Identifiable {
    let id = UUID()
    let title: String
    let details: String
    let severity: HealthIssueSeverity
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
