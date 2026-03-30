import SwiftUI
import AppKit

struct PerformanceView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var monitor = LiveSystemMetricsMonitor()
    @State private var selectedPaths = Set<String>()
    @State private var showCleanupConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.08, padding: 12)
            loadPanel
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.06, padding: 12)

            if model.isPerformanceScanRunning {
                ProgressView("Analyzing startup configuration...")
            }

            Group {
                if let report = model.performanceReport {
                    VStack(spacing: 10) {
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
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 0)
        }
        .padding(12)
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
        .onAppear {
            monitor.start()
            if model.performanceReport == nil {
                model.runPerformanceScan()
            }
        }
        .onDisappear {
            monitor.stop()
        }
    }

    private var header: some View {
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

            Button("Export Ops Log") {
                if let url = model.exportOperationLogReport() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var loadPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Load")
                .font(.headline)
            HStack(spacing: 10) {
                loadCard(
                    title: "CPU",
                    value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                    subtitle: "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%"
                )
                loadCard(
                    title: "Memory",
                    value: "\(Int(monitor.snapshot.memoryPressurePercent))%",
                    subtitle: "\(ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory)) of \(ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryTotalBytes, countStyle: .memory))"
                )
                loadCard(
                    title: "Network",
                    value: "↓ \(networkSpeedText(monitor.snapshot.networkDownBytesPerSecond))",
                    subtitle: "↑ \(networkSpeedText(monitor.snapshot.networkUpBytesPerSecond))"
                )
                loadCard(
                    title: "Battery",
                    value: batteryPrimaryText,
                    subtitle: batterySecondaryText
                )
            }
            if !monitor.snapshot.topCPUConsumers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top CPU Apps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(monitor.snapshot.topCPUConsumers.prefix(3))) { consumer in
                        HStack {
                            Text(consumer.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(consumer.cpuPercent))%")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func loadCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func networkSpeedText(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    private var batteryPrimaryText: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return "n/a" }
        return "\(percent)%"
    }

    private var batterySecondaryText: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return "No battery data" }
        let charging = monitor.snapshot.batteryIsCharging ?? false
        let minutes = monitor.snapshot.batteryMinutesRemaining
        if let minutes {
            let hours = minutes / 60
            let mins = minutes % 60
            if charging {
                return "\(percent)% · charging (\(hours)h \(mins)m)"
            }
            return "\(percent)% · \(hours)h \(mins)m left"
        }
        return charging ? "\(percent)% · charging" : "\(percent)%"
    }
}
