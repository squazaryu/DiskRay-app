import SwiftUI
import AppKit

extension PerformanceView {
    func batterySummaryStrip(_ snapshot: BatteryEnergySnapshot) -> some View {
        HStack(spacing: 10) {
            metricCard(
                title: t("Заряд", "Charge"),
                value: optionalPercent(snapshot.chargePercent),
                subtitle: batteryStateText(snapshot)
            )
            metricCard(
                title: "Health",
                value: optionalPercent(snapshot.healthPercent),
                subtitle: t("Циклы \(snapshot.cycleCount.map(String.init) ?? "n/a")", "Cycles \(snapshot.cycleCount.map(String.init) ?? "n/a")")
            )
            metricCard(
                title: t("Power Draw", "Power Draw"),
                value: optionalWatts(snapshot.powerDrawWatts),
                subtitle: timeEstimateText(snapshot)
            )
            metricCard(
                title: t("Температура", "Temperature"),
                value: optionalTemperature(snapshot.temperatureCelsius),
                subtitle: "V \(optionalVolts(snapshot.voltageVolts)) · A \(optionalAmps(snapshot.amperageAmps))"
            )
        }
    }

    func batteryConsumerRow(_ consumer: EnergyConsumerSnapshot, totalShare: Double) -> some View {
        let normalized = (consumer.estimatedDrainShare / totalShare) * 100
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(consumer.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(t(
                    "Estimated Drain Share \(String(format: "%.1f", consumer.estimatedDrainShare))%",
                    "Estimated Drain Share \(String(format: "%.1f", consumer.estimatedDrainShare))%"
                ))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.orange.opacity(0.76))
                        .frame(width: max(7, geo.size.width * CGFloat(min(max(normalized, 0), 100) / 100)))
                }
            }
            .frame(height: 7)

            HStack(spacing: 8) {
                StatusChip(title: "CPU \(Int(consumer.cpuPercent))%", tint: .blue)
                StatusChip(title: "MEM \(Int(consumer.memoryMB)) MB", tint: .teal)
                StatusChip(title: "EI \(String(format: "%.1f", consumer.currentEnergyImpact))", tint: .purple)
                if let wh = consumer.estimatedPower12hWh {
                    StatusChip(title: "12h \(String(format: "%.2f", wh)) Wh", tint: .orange)
                }
                if consumer.preventingSleep {
                    StatusChip(title: "Sleep Block", tint: .red)
                }
                if let gpu = consumer.highPowerGPUUsage {
                    StatusChip(title: gpu ? "GPU High" : "GPU Normal", tint: gpu ? .orange : .green)
                }
                if let appNap = consumer.appNapStatus {
                    StatusChip(title: appNap ? "App Nap On" : "App Nap Off", tint: appNap ? .green : .blue)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func startupEntryRow(_ entry: StartupEntry) -> some View {
        let selected = selectedPaths.contains(entry.url.path)
        let impact = startupImpactLevel(for: entry)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { selected },
                    set: { isOn in
                        if isOn { selectedPaths.insert(entry.url.path) }
                        else { selectedPaths.remove(entry.url.path) }
                    }
                ))
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(entry.source) · \(entry.url.path)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                StatusChip(title: impact.title, tint: impact.color)
                Text(ByteCountFormatter.string(fromByteCount: entry.sizeInBytes, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let width = maxStartupEntrySize > 0 ? geo.size.width * CGFloat(Double(entry.sizeInBytes) / Double(maxStartupEntrySize)) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(impact.color.opacity(0.72))
                        .frame(width: max(6, width))
                }
            }
            .frame(height: 6)

            HStack {
                Spacer()
                Button(t("Показать", "Reveal")) {
                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func historySparklineCard(title: String, values: [Double], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            MiniSparkline(values: values, tint: tint)
                .frame(height: 32)
            if let last = values.last {
                Text(String(format: "%.1f", last))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func metricCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func quickActionDeltaPanel(_ delta: QuickActionDeltaReport) -> some View {
        HStack(spacing: 8) {
            StatusChip(title: t("Действие: \(delta.actionTitle)", "Action: \(delta.actionTitle)"), tint: .blue)
            StatusChip(title: t("Элементы \(delta.beforeItems)→\(delta.afterItems)", "Items \(delta.beforeItems)->\(delta.afterItems)"), tint: .green)
            StatusChip(
                title: t(
                    "Размер \(ByteCountFormatter.string(fromByteCount: delta.beforeBytes, countStyle: .file))→\(ByteCountFormatter.string(fromByteCount: delta.afterBytes, countStyle: .file))",
                    "Size \(ByteCountFormatter.string(fromByteCount: delta.beforeBytes, countStyle: .file))->\(ByteCountFormatter.string(fromByteCount: delta.afterBytes, countStyle: .file))"
                ),
                tint: .orange
            )
            Spacer()
            Text(t("Обновлено \(relativeTime(delta.createdAt))", "Updated \(relativeTime(delta.createdAt))"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
