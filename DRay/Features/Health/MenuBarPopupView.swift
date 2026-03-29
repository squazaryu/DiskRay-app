import SwiftUI
import AppKit

struct MenuBarPopupView: View {
    @ObservedObject var model: RootViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DRay")
                        .font(.headline)
                    Text("Mac Health: \(healthTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(healthColor)
                }
                Spacer()
                Button("Open DRay") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            metricsGrid

            HStack(spacing: 8) {
                Button("Smart Scan") {
                    model.runUnifiedScan()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Space Scan") {
                    model.scanSelected()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .controlSize(.small)

                Button("Duplicates") {
                    model.scanDuplicatesInHome()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .controlSize(.small)
            }

            Divider()

            HStack {
                Text("Last diagnostic export")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = model.lastExportedDiagnosticURL {
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .controlSize(.small)
                } else {
                    Text("none")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    private var metricsGrid: some View {
        VStack(spacing: 6) {
            metricRow("Storage target", model.selectedTarget.name)
            metricRow("Startup entries", "\(model.performanceReport?.startupEntries.count ?? 0)")
            metricRow("Privacy categories", "\(model.privacyCategories.count)")
            metricRow("Duplicate groups", "\(model.duplicateGroups.count)")
        }
        .padding(10)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
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
        case "Good": return .green
        case "Fair": return .orange
        default: return .red
        }
    }
}
