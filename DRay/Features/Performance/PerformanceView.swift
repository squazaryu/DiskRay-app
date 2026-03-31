import SwiftUI
import AppKit

struct PerformanceView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var monitor = LiveSystemMetricsMonitor()
    @State private var selectedPaths = Set<String>()
    @State private var showCleanupConfirm = false
    @State private var pendingReliefAction: ReliefAction?
    @State private var showReliefConfirm = false
    @State private var reliefResultMessage: String?
    @State private var cpuTrend: [Double] = []
    @State private var memoryTrend: [Double] = []
    @State private var batteryTrend: [Double] = []
    @State private var trendTimestamps: [Date] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            loadPanel
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.06, padding: 12)

            if model.isPerformanceScanRunning {
                ProgressView("Analyzing startup configuration...")
            }

            Group {
                if let report = model.performanceReport {
                    VStack(spacing: 10) {
                        List {
                            Section("Recommendations") {
                                ForEach(report.recommendations) { rec in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .top, spacing: 8) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(rec.title).font(.headline)
                                                Text(rec.details).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 8)
                                            if let actionTitle = rec.actionTitle {
                                                Button(actionTitle) {
                                                    handleRecommendationAction(rec.action)
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                        }
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
        .confirmationDialog(
            reliefDialogTitle,
            isPresented: $showReliefConfirm,
            titleVisibility: .visible
        ) {
            Button(reliefActionTitle) {
                executeReliefAction()
            }
            Button("Cancel", role: .cancel) {
                pendingReliefAction = nil
            }
        }
        .alert("Live Load Adjustment", isPresented: Binding(
            get: { reliefResultMessage != nil },
            set: { if !$0 { reliefResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reliefResultMessage ?? "")
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
        .onReceive(monitor.$snapshot) { snapshot in
            appendTrendSample(snapshot)
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: "Performance",
            subtitle: "Startup diagnostics and maintenance recommendations."
        ) {
            HStack(spacing: 8) {
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

                Button("Reveal Crash Log") {
                    model.revealCrashTelemetry()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var loadPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Load")
                    .font(.headline)
                Spacer()
                Button("Reduce CPU") {
                    pendingReliefAction = .cpu
                    showReliefConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(cpuReliefCandidates.isEmpty)

                Button("Reduce Memory") {
                    pendingReliefAction = .memory
                    showReliefConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(memoryReliefCandidates.isEmpty)

                Button("Restore Priorities") {
                    let result = model.restoreAdjustedProcessPriorities(limit: 8)
                    let adjustedText = result.adjusted.isEmpty ? "0" : "\(result.adjusted.count): " + result.adjusted.joined(separator: ", ")
                    let failedText = result.failed.isEmpty ? "0" : "\(result.failed.count): " + result.failed.joined(separator: ", ")
                    let skippedText = result.skipped.isEmpty ? "0" : "\(result.skipped.count): " + result.skipped.joined(separator: ", ")
                    reliefResultMessage = "Restored \(adjustedText)\nFailed \(failedText)\nSkipped \(skippedText)"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.activeLoadReliefAdjustments == 0)
            }

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

            if let report = model.performanceReport {
                HStack(spacing: 10) {
                    loadCard(
                        title: "Startup entries",
                        value: "\(report.startupEntries.count)",
                        subtitle: ByteCountFormatter.string(fromByteCount: report.startupTotalBytes, countStyle: .file)
                    )
                    loadCard(
                        title: "Disk free",
                        value: report.diskFreeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "n/a",
                        subtitle: report.diskTotalBytes.map { "of " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
                    )
                    loadCard(
                        title: "Priority tweaks",
                        value: "\(model.activeLoadReliefAdjustments)",
                        subtitle: model.activeLoadReliefAdjustments == 0 ? "No active adjustments" : "Restore available"
                    )
                }
            }

            trendPanel

            if !monitor.snapshot.topCPUConsumers.isEmpty || !monitor.snapshot.topMemoryConsumers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Consumers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(consumerRows.prefix(4))) { consumer in
                        HStack {
                            Text(consumer.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text("CPU \(Int(consumer.cpuPercent))%")
                                .foregroundStyle(.secondary)
                            Text("MEM \(Int(consumer.memoryMB)) MB")
                                .foregroundStyle(.secondary)
                            Text("BAT \(String(format: "%.1f", consumer.batteryImpactScore))")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var consumerRows: [LiveConsumerRow] {
        var byName: [String: LiveConsumerRow] = [:]

        for consumer in monitor.snapshot.topCPUConsumers {
            let key = normalizedConsumerKey(consumer.name)
            byName[key] = LiveConsumerRow(
                id: key,
                displayName: shortConsumerName(consumer.name),
                cpuPercent: consumer.cpuPercent,
                memoryMB: consumer.memoryMB,
                batteryImpactScore: consumer.batteryImpactScore
            )
        }

        for consumer in monitor.snapshot.topMemoryConsumers {
            let key = normalizedConsumerKey(consumer.name)
            if var existing = byName[key] {
                existing.cpuPercent = max(existing.cpuPercent, consumer.cpuPercent)
                existing.memoryMB = max(existing.memoryMB, consumer.memoryMB)
                existing.batteryImpactScore = max(existing.batteryImpactScore, consumer.batteryImpactScore)
                byName[key] = existing
            } else {
                byName[key] = LiveConsumerRow(
                    id: key,
                    displayName: shortConsumerName(consumer.name),
                    cpuPercent: consumer.cpuPercent,
                    memoryMB: consumer.memoryMB,
                    batteryImpactScore: consumer.batteryImpactScore
                )
            }
        }

        return byName.values.sorted { lhs, rhs in
            if lhs.cpuPercent != rhs.cpuPercent {
                return lhs.cpuPercent > rhs.cpuPercent
            }
            return lhs.memoryMB > rhs.memoryMB
        }
    }

    private func normalizedConsumerKey(_ name: String) -> String {
        shortConsumerName(name).lowercased()
    }

    private func shortConsumerName(_ name: String) -> String {
        let ns = name as NSString
        let last = ns.lastPathComponent
        if last.hasSuffix(".app") {
            return String(last.dropLast(4))
        }
        if !last.isEmpty && last != "/" {
            return last
        }
        let components = name.split(separator: "/").map(String.init)
        if let first = components.first(where: { $0.hasSuffix(".app") }) {
            return first.replacingOccurrences(of: ".app", with: "")
        }
        return name
    }

    private func loadCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Load Trends")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                trendCard(
                    title: "CPU",
                    color: .blue,
                    values: cpuTrend,
                    avg5m: averageForWindow(cpuTrend, seconds: 5 * 60),
                    avg15m: averageForWindow(cpuTrend, seconds: 15 * 60)
                )
                trendCard(
                    title: "Memory",
                    color: .purple,
                    values: memoryTrend,
                    avg5m: averageForWindow(memoryTrend, seconds: 5 * 60),
                    avg15m: averageForWindow(memoryTrend, seconds: 15 * 60)
                )
                trendCard(
                    title: "Battery",
                    color: .green,
                    values: batteryTrend,
                    avg5m: averageForWindow(batteryTrend, seconds: 5 * 60),
                    avg15m: averageForWindow(batteryTrend, seconds: 15 * 60)
                )
            }
        }
    }

    private func trendCard(
        title: String,
        color: Color,
        values: [Double],
        avg5m: Double?,
        avg15m: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("5m \(formatPercent(avg5m))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("15m \(formatPercent(avg15m))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            MiniSparkline(values: values, color: color)
                .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func appendTrendSample(_ snapshot: LiveSystemSnapshot) {
        trendTimestamps.append(snapshot.updatedAt)
        cpuTrend.append(snapshot.cpuLoadPercent)
        memoryTrend.append(snapshot.memoryPressurePercent)
        let batterySample = snapshot.batteryLevelPercent.map(Double.init) ?? batteryTrend.last ?? 0
        batteryTrend.append(batterySample)

        let maxSamples = 15 * 60
        if trendTimestamps.count > maxSamples {
            let overflow = trendTimestamps.count - maxSamples
            trendTimestamps.removeFirst(overflow)
            cpuTrend.removeFirst(overflow)
            memoryTrend.removeFirst(overflow)
            batteryTrend.removeFirst(overflow)
        }
    }

    private func averageForWindow(_ values: [Double], seconds: Int) -> Double? {
        guard !values.isEmpty else { return nil }
        let points = min(seconds, values.count)
        guard points > 0 else { return nil }
        let subset = values.suffix(points)
        let sum = subset.reduce(0, +)
        return sum / Double(points)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return "\(Int(value.rounded()))%"
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
            return "Adjust live load?"
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
        let result: LoadReliefResult
        switch action {
        case .cpu:
            result = model.reduceCPULoad(consumers: cpuReliefCandidates, limit: 3)
        case .memory:
            result = model.reduceMemoryLoad(consumers: memoryReliefCandidates, limit: 3)
        }

        pendingReliefAction = nil
        model.runPerformanceScan()
        let adjustedText = result.adjusted.isEmpty ? "0" : "\(result.adjusted.count): " + result.adjusted.joined(separator: ", ")
        let failedText = result.failed.isEmpty ? "0" : "\(result.failed.count): " + result.failed.joined(separator: ", ")
        let skippedText = result.skipped.isEmpty ? "0" : "\(result.skipped.count): " + result.skipped.joined(separator: ", ")
        reliefResultMessage = "Adjusted \(adjustedText)\nFailed \(failedText)\nSkipped \(skippedText)"
    }

    private func handleRecommendationAction(_ action: PerformanceRecommendationAction) {
        switch action {
        case .selectAllStartup:
            guard let report = model.performanceReport else { return }
            selectedPaths = Set(report.startupEntries.map { $0.url.path })
        case .selectHeavyStartup:
            guard let report = model.performanceReport else { return }
            let heavy = report.startupEntries
                .filter { $0.sizeInBytes >= 100 * 1_048_576 }
                .map { $0.url.path }
            selectedPaths = Set(heavy)
        case .openSmartCare:
            model.openSection(.smartCare)
            model.runSmartScan()
        case .runDiagnostics:
            model.runPerformanceScan()
        case .none:
            break
        }
    }
}

private enum ReliefAction {
    case cpu
    case memory
}

private struct LiveConsumerRow: Identifiable {
    let id: String
    let displayName: String
    var cpuPercent: Double
    var memoryMB: Double
    var batteryImpactScore: Double
}

private struct MiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.08))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let span = max(1, maxValue - minValue)
        let step = size.width / CGFloat(max(1, values.count - 1))

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let normalized = (value - minValue) / span
            let y = size.height - CGFloat(normalized) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}
