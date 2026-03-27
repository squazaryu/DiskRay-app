import SwiftUI
import AppKit

struct PerformanceView: View {
    @ObservedObject var model: RootViewModel
    @State private var selectedPaths = Set<String>()
    @State private var showCleanupConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance")
                        .font(.title2.bold())
                    Text("Startup diagnostics and maintenance recommendations.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run Diagnostics") { model.runPerformanceScan() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isPerformanceScanRunning)

                Button("Disable Selected") {
                    showCleanupConfirm = true
                }
                .buttonStyle(.bordered)
                .disabled(selectedEntries.isEmpty)
            }

            if model.isPerformanceScanRunning {
                ProgressView("Analyzing startup configuration...")
            }

            if let report = model.performanceReport {
                HStack {
                    statCard(
                        "Startup entries",
                        "\(report.startupEntries.count)",
                        caption: ByteCountFormatter.string(fromByteCount: report.startupTotalBytes, countStyle: .file)
                    )
                    statCard(
                        "Disk free",
                        report.diskFreeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "n/a",
                        caption: report.diskTotalBytes.map { "of " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
                    )
                    Spacer()
                }

                List {
                    Section("Recommendations") {
                        ForEach(report.recommendations) { rec in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rec.title).font(.headline)
                                Text(rec.details).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Startup Entries") {
                        ForEach(report.startupEntries) { entry in
                            HStack {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { selectedPaths.contains(entry.url.path) },
                                        set: { isOn in
                                            if isOn { selectedPaths.insert(entry.url.path) }
                                            else { selectedPaths.remove(entry.url.path) }
                                        }
                                    )
                                )
                                .labelsHidden()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                    Text("\(entry.source) · \(entry.url.path)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: entry.sizeInBytes, countStyle: .file))
                                    .font(.caption)
                                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                if let cleanup = model.startupCleanupReport {
                    Text("Last startup cleanup: moved \(cleanup.moved), failed \(cleanup.failed), skipped \(cleanup.skippedProtected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !model.isPerformanceScanRunning {
                ContentUnavailableView(
                    "No Diagnostics Yet",
                    systemImage: "speedometer",
                    description: Text("Run diagnostics to inspect startup pressure and maintenance opportunities.")
                )
            }
        }
        .padding()
        .confirmationDialog(
            "Disable selected startup entries?",
            isPresented: $showCleanupConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                model.cleanupStartupEntries(selectedEntries)
                selectedPaths.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected startup entries will be moved to Trash.")
        }
    }

    private func statCard(_ title: String, _ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
            if !caption.isEmpty {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var selectedEntries: [StartupEntry] {
        guard let report = model.performanceReport else { return [] }
        return report.startupEntries.filter { selectedPaths.contains($0.url.path) }
    }
}
