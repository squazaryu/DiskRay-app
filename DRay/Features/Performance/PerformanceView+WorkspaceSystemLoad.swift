import SwiftUI

extension PerformanceView {
    var systemLoadWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("Live Load Diagnostics", "Live Load Diagnostics"))
                    .font(.headline)
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

            HStack(spacing: 10) {
                metricCard(
                    title: "CPU",
                    value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                    subtitle: t("Пользователь \(Int(monitor.snapshot.cpuUserPercent))% · Система \(Int(monitor.snapshot.cpuSystemPercent))%", "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%")
                )
                metricCard(
                    title: t("Память", "Memory"),
                    value: "\(Int(monitor.snapshot.memoryPressurePercent))%",
                    subtitle: "\(ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryTotalBytes, countStyle: .memory))"
                )
                metricCard(
                    title: t("Топ CPU", "Top CPU"),
                    value: topCPUConsumerName,
                    subtitle: topCPUConsumerValue
                )
                metricCard(
                    title: t("Топ RAM", "Top RAM"),
                    value: topMemoryConsumerName,
                    subtitle: topMemoryConsumerValue
                )
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CPU Trend")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    MiniSparkline(values: cpuTrend, tint: .orange)
                        .frame(height: 34)
                }
                .padding(9)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Память trend", "Memory Trend"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    MiniSparkline(values: memoryTrend, tint: .blue)
                        .frame(height: 34)
                }
                .padding(9)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Вклад потребителей", "Consumer Contribution"))
                    .font(.subheadline.weight(.semibold))
                let ranked = rankedLiveConsumers
                ForEach(Array(ranked.prefix(6).enumerated()), id: \.offset) { index, consumer in
                    let share = rankedContribution(for: consumer, in: ranked)
                    RankedShareBar(
                        title: consumer.displayName,
                        subtitle: "CPU \(Int(consumer.cpuPercent))% · MEM \(Int(consumer.memoryMB)) MB · BAT \(String(format: "%.1f", consumer.batteryImpactScore))",
                        percentage: share,
                        accent: index < 2 ? .orange : .blue
                    )
                }
                if ranked.isEmpty {
                    Text(t("Активные потребители не обнаружены.", "No active consumers detected."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
