import SwiftUI

extension PerformanceView {
    var batteryEnergyWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusChip(title: t("System Fact", "System Fact"), tint: .blue)
                StatusChip(title: t("DiskRay Estimate", "DiskRay Estimate"), tint: .orange)
                Spacer()
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(t("Power Consumers", "Power Consumers"))
                            .font(.headline)
                        Spacer()
                        Text(report.estimatedMetricTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Text(report.estimatedMetricExplanation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

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
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
