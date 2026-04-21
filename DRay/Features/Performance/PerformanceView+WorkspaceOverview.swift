import SwiftUI

extension PerformanceView {
    var overviewWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            healthStrip

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Фокус сейчас", "Focus Now"))
                        .font(.headline)

                    if let top = model.performance.report?.recommendations.first {
                        Text(top.title)
                            .font(.subheadline.weight(.semibold))
                        Text(top.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        HStack(spacing: 8) {
                            if let action = top.actionTitle {
                                Button(action) {
                                    handleRecommendationAction(top.action)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            Button(t("Открыть автозапуск", "Open Startup")) {
                                workspaceTab = .startup
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(t("Открыть нагрузку", "Open System Load")) {
                                workspaceTab = .systemLoad
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Text(t(
                            "Запусти диагностику, чтобы сформировать приоритетное действие.",
                            "Run diagnostics to generate a prioritized action."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Быстрая сводка", "Quick Summary"))
                        .font(.headline)

                    DiagnosticBurdenBar(
                        value: monitor.snapshot.cpuLoadPercent,
                        label: "CPU",
                        detail: t("Текущая вычислительная нагрузка", "Current compute load")
                    )
                    DiagnosticBurdenBar(
                        value: monitor.snapshot.memoryPressurePercent,
                        label: t("Память", "Memory"),
                        detail: t("Давление памяти системы", "System memory pressure")
                    )
                    DiagnosticBurdenBar(
                        value: startupBurdenValue,
                        label: t("Автозапуск", "Startup"),
                        detail: t("Бремя запуска по количеству и объёму", "Launch burden by count and footprint")
                    )
                    if let networkQualityValue {
                        DiagnosticBurdenBar(
                            value: networkQualityValue,
                            label: t("Сеть", "Network"),
                            detail: networkQualityLabel
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let delta = model.performanceQuickActionDelta {
                quickActionDeltaPanel(delta)
            }
        }
    }

    var healthStrip: some View {
        HStack(spacing: 8) {
            StatusChip(title: "CPU: \(severityLabel(for: monitor.snapshot.cpuLoadPercent))", tint: severityColor(for: monitor.snapshot.cpuLoadPercent))
            StatusChip(title: "RAM: \(severityLabel(for: monitor.snapshot.memoryPressurePercent))", tint: severityColor(for: monitor.snapshot.memoryPressurePercent))
            StatusChip(title: "\(t("Батарея", "Battery")): \(batteryHealthLabel)", tint: batteryHealthColor)
            StatusChip(title: "\(t("Автозапуск", "Startup")): \(severityLabel(for: startupBurdenValue))", tint: severityColor(for: startupBurdenValue))
            if let networkStatusChip {
                StatusChip(title: networkStatusChip.title, tint: networkStatusChip.tint)
            }
            Spacer(minLength: 8)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
