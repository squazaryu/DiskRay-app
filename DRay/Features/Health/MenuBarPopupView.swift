import SwiftUI
import AppKit

struct MenuBarPopupView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var monitor = LiveSystemMetricsMonitor()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            topCards
            bottomCards
            extraCards
            recommendationCard
            footer
        }
        .padding(12)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                Text(model.selectedTarget.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Updated \(monitor.snapshot.updatedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(healthColor.opacity(0.22))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "bolt.heart.fill").foregroundStyle(healthColor))
        }
    }

    private var topCards: some View {
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
                subtitle: "Physical RAM",
                value: "\(Int(monitor.snapshot.memoryPressurePercent))% pressure",
                actionTitle: "Open DRay",
                action: { NSApp.activate(ignoringOtherApps: true) }
            )
        }
    }

    private var bottomCards: some View {
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
    }

    private var extraCards: some View {
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

            VStack(alignment: .leading, spacing: 1) {
                Text("Net ↓ \(networkSpeedText(monitor.snapshot.networkDownBytesPerSecond))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Net ↑ \(networkSpeedText(monitor.snapshot.networkUpBytesPerSecond))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = model.lastExportedDiagnosticURL {
                Button("Reveal Report") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .controlSize(.small)
            }
        }
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
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
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

    private var cardBackground: some ShapeStyle {
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05)
    }

    private var recommendationText: String {
        if monitor.snapshot.cpuLoadPercent > 75 {
            return "High CPU load detected right now. Close heavy apps to reduce temperature and fan noise."
        }
        if monitor.snapshot.memoryPressurePercent > 85 {
            return "Memory pressure is high. Consider closing heavy apps and cleaning background startup items."
        }
        if model.duplicateGroups.count > 0 {
            return "Found duplicates that can free \(ByteCountFormatter.string(fromByteCount: duplicateReclaimableBytes, countStyle: .file))."
        }
        if (model.performanceReport?.startupEntries.count ?? 0) > 12 {
            return "Too many startup items detected. Review startup entries to improve boot speed."
        }
        return "Run Smart Scan to refresh system diagnostics and cleanup recommendations."
    }

    private var recommendationActionTitle: String {
        if monitor.snapshot.cpuLoadPercent > 75 || monitor.snapshot.memoryPressurePercent > 85 {
            return "Open Performance"
        }
        if model.duplicateGroups.count > 0 { return "Review Duplicates" }
        if (model.performanceReport?.startupEntries.count ?? 0) > 12 { return "Open Performance" }
        return "Run Smart Scan"
    }

    private func recommendationAction() {
        if monitor.snapshot.cpuLoadPercent > 75 || monitor.snapshot.memoryPressurePercent > 85 {
            model.runPerformanceScan()
            return
        }
        if model.duplicateGroups.count > 0 {
            model.scanDuplicatesInHome()
            return
        }
        if (model.performanceReport?.startupEntries.count ?? 0) > 12 {
            model.runPerformanceScan()
            return
        }
        model.runUnifiedScan()
    }

    private var duplicateReclaimableBytes: Int64 {
        model.duplicateGroups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
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

    private func networkSpeedText(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.10)
    }

    private var batteryRisk: Int {
        guard let level = monitor.snapshot.batteryLevelPercent else { return 0 }
        if level < 20 { return 2 }
        if level < 40 { return 1 }
        return 0
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
        if monitor.snapshot.cpuLoadPercent > 85 || monitor.snapshot.memoryPressurePercent > 90 || batteryRisk == 2 {
            return "Needs attention"
        }
        if monitor.snapshot.cpuLoadPercent > 65 || monitor.snapshot.memoryPressurePercent > 75 || batteryRisk == 1 {
            return "Fair"
        }
        let startupCount = model.performanceReport?.startupEntries.count ?? 0
        let duplicateCount = model.duplicateGroups.count
        if startupCount > 30 || duplicateCount > 100 {
            return "Needs attention"
        }
        if startupCount > 10 || duplicateCount > 20 {
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
