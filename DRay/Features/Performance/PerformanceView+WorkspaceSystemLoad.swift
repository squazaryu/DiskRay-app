import SwiftUI

extension PerformanceView {
    var systemLoadWorkspace: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Live Load Diagnostics", "Live Load Diagnostics"))
                        .font(.headline)
                    Text(t("CPU, memory pressure and process contribution in one live view.", "CPU, memory pressure and process contribution in one live view."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Снизить CPU", "Reduce CPU")) {
                    pendingReliefAction = .cpu
                    showReliefConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(cpuReliefCandidates.isEmpty)

                Button(t("Снизить память", "Reduce Memory")) {
                    pendingReliefAction = .memory
                    showReliefConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(memoryReliefCandidates.isEmpty)

                Button(t("Вернуть приоритеты", "Restore Priorities")) {
                    let result = model.restoreAdjustedProcessPriorities(limit: 8)
                    let adjustedText = result.adjusted.isEmpty ? "0" : "\(result.adjusted.count): " + result.adjusted.joined(separator: ", ")
                    let failedText = result.failed.isEmpty ? "0" : "\(result.failed.count): " + result.failed.joined(separator: ", ")
                    let skippedText = result.skipped.isEmpty ? "0" : "\(result.skipped.count): " + result.skipped.joined(separator: ", ")
                    reliefResultMessage = t(
                        "Восстановлено \(adjustedText)\nОшибки \(failedText)\nПропущено \(skippedText)",
                        "Restored \(adjustedText)\nFailed \(failedText)\nSkipped \(skippedText)"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.performance.activeLoadReliefAdjustments == 0)
            }

            HStack(spacing: layoutMetrics.cardSpacing) {
                DRayCompactInfoTile(
                    title: "CPU",
                    value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                    subtitle: t("User \(Int(monitor.snapshot.cpuUserPercent)) · System \(Int(monitor.snapshot.cpuSystemPercent))", "User \(Int(monitor.snapshot.cpuUserPercent)) · System \(Int(monitor.snapshot.cpuSystemPercent))"),
                    icon: "cpu",
                    tint: .blue,
                    progress: min(1, monitor.snapshot.cpuLoadPercent / 100)
                )
                DRayCompactInfoTile(
                    title: t("Память", "Memory"),
                    value: "\(Int(monitor.snapshot.memoryPressurePercent))%",
                    subtitle: ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory),
                    icon: "memorychip",
                    tint: .purple,
                    progress: min(1, monitor.snapshot.memoryPressurePercent / 100)
                )
                DRayCompactInfoTile(
                    title: t("Топ CPU", "Top CPU"),
                    value: topCPUConsumerName,
                    subtitle: topCPUConsumerValue,
                    icon: "flame",
                    tint: .orange,
                    progress: (monitor.snapshot.topCPUConsumers.first?.cpuPercent ?? 0) / 100
                )
                DRayCompactInfoTile(
                    title: t("Топ RAM", "Top RAM"),
                    value: topMemoryConsumerName,
                    subtitle: topMemoryConsumerValue,
                    icon: "gauge.with.dots.needle.67percent",
                    tint: .teal,
                    progress: min(1, (monitor.snapshot.topMemoryConsumers.first?.memoryMB ?? 0) / 4096)
                )
            }

            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    performanceCardTitle(t("Pressure Trend", "Pressure Trend"), icon: "waveform.path.ecg", tint: .blue)
                    ZStack {
                        DRaySparklineView(values: cpuTrend, tint: .blue, lineWidth: 1.9)
                        DRaySparklineView(values: memoryTrend, tint: .purple, lineWidth: 1.9)
                    }
                    .frame(height: 118)
                    HStack(spacing: 10) {
                        performanceLegendDot("CPU \(Int(monitor.snapshot.cpuLoadPercent))%", tint: .blue)
                        performanceLegendDot(t("Память \(Int(monitor.snapshot.memoryPressurePercent))%", "Memory \(Int(monitor.snapshot.memoryPressurePercent))%"), tint: .purple)
                        Spacer()
                        Text(t("Live sample", "Live sample"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                .padding(layoutMetrics.cardSpacing)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)

                VStack(alignment: .leading, spacing: 8) {
                    performanceCardTitle(t("Relief Actions", "Relief Actions"), icon: "bolt.heart", tint: .green)
                    DRayActionRow(
                        title: t("Reduce CPU", "Reduce CPU"),
                        subtitle: t("Lower priority for active CPU leaders.", "Lower priority for active CPU leaders."),
                        icon: "cpu",
                        tint: .blue,
                        actionTitle: t("Run", "Run")
                    ) {
                        pendingReliefAction = .cpu
                        showReliefConfirm = true
                    }
                    .disabled(cpuReliefCandidates.isEmpty)

                    DRayActionRow(
                        title: t("Reduce Memory", "Reduce Memory"),
                        subtitle: t("Lower priority for memory-heavy apps.", "Lower priority for memory-heavy apps."),
                        icon: "memorychip",
                        tint: .purple,
                        actionTitle: t("Run", "Run")
                    ) {
                        pendingReliefAction = .memory
                        showReliefConfirm = true
                    }
                    .disabled(memoryReliefCandidates.isEmpty)

                    DRayActionRow(
                        title: t("Restore Priorities", "Restore Priorities"),
                        subtitle: t("Undo DRay load-relief adjustments.", "Undo DRay load-relief adjustments."),
                        icon: "arrow.counterclockwise",
                        tint: .orange,
                        actionTitle: t("Restore", "Restore")
                    ) {
                        let result = model.restoreAdjustedProcessPriorities(limit: 8)
                        let adjustedText = result.adjusted.isEmpty ? "0" : "\(result.adjusted.count): " + result.adjusted.joined(separator: ", ")
                        let failedText = result.failed.isEmpty ? "0" : "\(result.failed.count): " + result.failed.joined(separator: ", ")
                        let skippedText = result.skipped.isEmpty ? "0" : "\(result.skipped.count): " + result.skipped.joined(separator: ", ")
                        reliefResultMessage = t(
                            "Восстановлено \(adjustedText)\nОшибки \(failedText)\nПропущено \(skippedText)",
                            "Restored \(adjustedText)\nFailed \(failedText)\nSkipped \(skippedText)"
                        )
                    }
                    .disabled(model.performance.activeLoadReliefAdjustments == 0)
                }
                .frame(width: 330, alignment: .topLeading)
                .frame(minHeight: 190, alignment: .topLeading)
                .padding(layoutMetrics.cardSpacing)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                performanceCardTitle(t("Вклад потребителей", "Consumer Contribution"), icon: "app.badge", tint: .blue)
                let ranked = rankedLiveConsumers
                ForEach(Array(ranked.prefix(6).enumerated()), id: \.offset) { index, consumer in
                    DRayRankedBarRow(
                        rank: index + 1,
                        title: consumer.displayName,
                        subtitle: "CPU \(Int(consumer.cpuPercent))% · MEM \(Int(consumer.memoryMB)) MB · BAT \(String(format: "%.1f", consumer.batteryImpactScore))",
                        value: "\(Int(rankedContribution(for: consumer, in: ranked)))%",
                        progress: rankedContribution(for: consumer, in: ranked) / 100,
                        tint: index < 2 ? .orange : .blue,
                        icon: "app.fill"
                    )
                }
                if ranked.isEmpty {
                    Text(t("Активные потребители не обнаружены.", "No active consumers detected."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(layoutMetrics.cardSpacing)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
        }
    }
}
