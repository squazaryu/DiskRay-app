import SwiftUI
import AppKit

struct HealthPopupView: View {
    @ObservedObject var model: RootViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            statusStrip

            HStack(alignment: .top, spacing: 10) {
                diagnosticsCards
                focusPanel
            }

            actionsRow
        }
        .padding(18)
        .frame(width: 760, height: 560)
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.21, blue: 0.33), Color(red: 0.07, green: 0.12, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if model.performanceReport == nil {
                model.runPerformanceScan()
            }
            if model.privacyCategories.isEmpty {
                model.runPrivacyScan()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Mac Health")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(Host.current().localizedName ?? "Mac") · \(healthStateLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            GlassPillBadge(title: healthStateLabel, tint: healthTint)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            popupStatusTile(title: "Storage", value: storageStatus)
            popupStatusTile(title: "Memory", value: memoryStatus)
            popupStatusTile(title: "Startup", value: startupStatus)
            popupStatusTile(title: "Privacy", value: privacyStatus)
        }
    }

    private var diagnosticsCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                diagnosticsCard("Storage", detail: storageValue, hint: "Capacity and cleanup headroom")
                diagnosticsCard("Memory", detail: memoryValue, hint: "Current pressure indicator")
            }

            HStack(spacing: 10) {
                diagnosticsCard("Startup", detail: startupValue, hint: "Boot-time impact footprint")
                diagnosticsCard("Privacy", detail: privacyValue, hint: "Trace categories currently found")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Now")
                .font(.headline)
                .foregroundStyle(.white)
            Text(recommendation)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))

            Divider().overlay(.white.opacity(0.16))

            VStack(alignment: .leading, spacing: 6) {
                focusRow("Main issue", focusHeadline)
                focusRow("Next step", focusActionLabel)
                focusRow("Scope", focusScopeLabel)
            }

            Spacer(minLength: 8)

            Text("Use full scan when you need a complete storage + performance + privacy baseline.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.78))
                .font(.caption)
        }
        .padding(14)
        .frame(width: 248)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button("Run Full Smart Scan") {
                model.runUnifiedScan()
            }
            .buttonStyle(.borderedProminent)

            Button("Open Performance") {
                model.selectedSection = .performance
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Open Privacy") {
                model.selectedSection = .privacy
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Export Report") {
                if let url = model.exportDiagnosticReport() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func diagnosticsCard(_ title: String, detail: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(hint)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func popupStatusTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.70))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func focusRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))
            Spacer(minLength: 6)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    private var storageValue: String {
        guard let report = model.performanceReport, let free = report.diskFreeBytes else { return "No data" }
        return "Available: \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))"
    }

    private var memoryValue: String {
        "Pressure: baseline check"
    }

    private var startupValue: String {
        guard let report = model.performanceReport else { return "No data" }
        return "\(report.startupEntries.count) startup entries"
    }

    private var privacyValue: String {
        "\(model.privacyCategories.count) categories detected"
    }

    private var healthStateLabel: String {
        let startup = model.performanceReport?.startupEntries.count ?? 0
        if startup > 40 { return "Needs Attention" }
        if startup > 20 { return "Fair" }
        return "Good"
    }

    private var healthTint: Color {
        switch healthStateLabel {
        case "Needs Attention":
            return .orange
        case "Fair":
            return .yellow
        default:
            return .green
        }
    }

    private var storageStatus: String {
        guard let free = model.performanceReport?.diskFreeBytes else { return "Unknown" }
        let freeGB = Double(free) / 1_073_741_824
        if freeGB < 30 { return "Low" }
        if freeGB < 80 { return "Medium" }
        return "Healthy"
    }

    private var memoryStatus: String {
        model.performanceReport == nil ? "Unknown" : "Baseline"
    }

    private var startupStatus: String {
        let count = model.performanceReport?.startupEntries.count ?? 0
        if count >= 36 { return "Heavy" }
        if count >= 20 { return "Watch" }
        return "Normal"
    }

    private var privacyStatus: String {
        let count = model.privacyCategories.count
        if count >= 5 { return "Review" }
        if count >= 2 { return "Moderate" }
        return "Light"
    }

    private var focusHeadline: String {
        if privacyStatus == "Review" { return "Privacy traces" }
        if startupStatus == "Heavy" { return "Startup burden" }
        if storageStatus == "Low" { return "Low free storage" }
        return "Preventive scan"
    }

    private var focusActionLabel: String {
        if privacyStatus == "Review" { return "Open Privacy" }
        if startupStatus == "Heavy" { return "Open Performance" }
        return "Run Full Smart Scan"
    }

    private var focusScopeLabel: String {
        if privacyStatus == "Review" { return "Privacy + Recovery" }
        if startupStatus == "Heavy" { return "Startup + Load" }
        if storageStatus == "Low" { return "Storage + Cleanup" }
        return "Global"
    }

    private var recommendation: String {
        if model.privacyCategories.count > 2 {
            return "Privacy traces detected. Run privacy cleanup after review."
        }
        if let startup = model.performanceReport?.startupEntries.count, startup > 20 {
            return "Disable non-essential startup entries to improve boot performance."
        }
        return "Run full smart scan to keep storage and system health in optimal state."
    }
}
