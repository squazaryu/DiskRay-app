import SwiftUI
import AppKit

struct MenuBarPopupView: View {
    @ObservedObject var model: RootViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.14, blue: 0.34), Color(red: 0.10, green: 0.11, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                header
                topCards
                bottomCards
                recommendationCard
                footer
            }
            .padding(12)
        }
        .frame(width: 430)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Health: \(healthTitle)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(model.selectedTarget.name)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
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
                value: diskValue,
                actionTitle: "Free Up",
                action: { model.scanSelected() }
            )
            metricCard(
                title: "Memory",
                subtitle: "Physical RAM",
                value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory),
                actionTitle: "Open DRay",
                action: { NSApp.activate(ignoringOtherApps: true) }
            )
        }
    }

    private var bottomCards: some View {
        HStack(spacing: 10) {
            metricCard(
                title: "My Clutter",
                subtitle: "Duplicate groups",
                value: "\(model.duplicateGroups.count)",
                actionTitle: "Scan",
                action: { model.scanDuplicatesInHome() }
            )
            metricCard(
                title: "Startup",
                subtitle: "Login & launch items",
                value: "\(model.performanceReport?.startupEntries.count ?? 0)",
                actionTitle: "Diagnose",
                action: { model.runPerformanceScan() }
            )
        }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Recommendation")
                .font(.headline)
                .foregroundStyle(.white)
            Text(recommendationText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
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
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            HStack {
                Spacer()
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.32))
                    .foregroundStyle(.white)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color.white.opacity(0.13), Color.white.opacity(0.09)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var recommendationText: String {
        if model.duplicateGroups.count > 0 {
            return "Found duplicates that can free \(ByteCountFormatter.string(fromByteCount: duplicateReclaimableBytes, countStyle: .file))."
        }
        if (model.performanceReport?.startupEntries.count ?? 0) > 12 {
            return "Too many startup items detected. Review startup entries to improve boot speed."
        }
        return "Run Smart Scan to refresh system diagnostics and cleanup recommendations."
    }

    private var recommendationActionTitle: String {
        if model.duplicateGroups.count > 0 { return "Review Duplicates" }
        if (model.performanceReport?.startupEntries.count ?? 0) > 12 { return "Open Performance" }
        return "Run Smart Scan"
    }

    private func recommendationAction() {
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
        if let free = diskStats?.free {
            return "Available \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))"
        }
        return "Storage details unavailable"
    }

    private var diskValue: String {
        if let total = diskStats?.total {
            return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
        return "n/a"
    }

    private var diskStats: (total: Int64, free: Int64)? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = (attrs[.systemSize] as? NSNumber)?.int64Value,
              let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value else {
            return nil
        }
        return (total: total, free: free)
    }

    private var healthTitle: String {
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
        case "Good": return Color(red: 0.38, green: 0.98, blue: 0.88)
        case "Fair": return Color(red: 1.0, green: 0.80, blue: 0.30)
        default: return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
    }
}
