import SwiftUI
import AppKit

struct PerformanceView: View {
    @ObservedObject var model: RootViewModel

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
            } else if !model.isPerformanceScanRunning {
                ContentUnavailableView(
                    "No Diagnostics Yet",
                    systemImage: "speedometer",
                    description: Text("Run diagnostics to inspect startup pressure and maintenance opportunities.")
                )
            }
        }
        .padding()
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
}
