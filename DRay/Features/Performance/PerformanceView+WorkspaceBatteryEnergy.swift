import SwiftUI

extension PerformanceView {
    var batteryEnergyWorkspace: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Battery & Energy", "Battery & Energy"))
                        .font(.headline)
                    Text(t("System facts stay separate from DRay's drain estimate.", "System facts stay separate from DRay's drain estimate."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusChip(title: t("System Fact", "System Fact"), tint: .blue)
                StatusChip(title: t("DRay Estimate", "DRay Estimate"), tint: .orange)
                Button(t("Обновить", "Refresh")) {
                    model.loadBatteryEnergyReport(force: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.performance.isBatteryEnergyLoading)
            }

            if model.performance.isBatteryEnergyLoading && model.performance.batteryEnergyReport == nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Считываем battery и energy телеметрию...", "Loading battery and energy telemetry..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let report = model.performance.batteryEnergyReport {
                batterySummaryStrip(report.battery)

                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    VStack(alignment: .leading, spacing: 10) {
                        performanceCardTitle(t("Power Consumers", "Power Consumers"), icon: "bolt.batteryblock", tint: .orange)
                        Text(report.estimatedMetricExplanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if report.consumers.isEmpty {
                            Text(t("Активные high-impact процессы не обнаружены.", "No high-impact processes detected right now."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            let totalShare = max(report.consumers.prefix(8).reduce(0.0) { $0 + $1.estimatedDrainShare }, 0.1)
                            ForEach(Array(report.consumers.prefix(8).enumerated()), id: \.offset) { _, consumer in
                                batteryConsumerRow(consumer, totalShare: totalShare)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(layoutMetrics.cardSpacing)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        performanceCardTitle(t("Estimate Honesty", "Estimate Honesty"), icon: "checkmark.seal", tint: .blue)
                        Text(report.estimatedMetricTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(t(
                            "macOS reports facts like charge, cycle count and state. DRay estimates relative drain from process activity and energy impact.",
                            "macOS reports facts like charge, cycle count and state. DRay estimates relative drain from process activity and energy impact."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                        Spacer()
                        if let top = report.consumers.first {
                            DRayRankedBarRow(
                                rank: 1,
                                title: top.displayName,
                                subtitle: "CPU \(Int(top.cpuPercent))% · MEM \(Int(top.memoryMB)) MB",
                                value: "\(String(format: "%.1f", top.estimatedDrainShare))%",
                                progress: min(1, top.estimatedDrainShare / max(report.consumers.prefix(8).reduce(0.0) { $0 + $1.estimatedDrainShare }, 0.1)),
                                tint: .orange,
                                icon: "flame.fill"
                            )
                        }
                    }
                    .frame(width: 320, alignment: .topLeading)
                    .frame(minHeight: 260, alignment: .topLeading)
                    .padding(layoutMetrics.cardSpacing)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
                }
            } else {
                Text(t(
                    "Battery/energy данные пока недоступны на этом Mac.",
                    "Battery/energy data is currently unavailable on this Mac."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
