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
                    model.loadEnergyModeSettings(force: true)
                }
                .buttonStyle(DRaySecondaryButtonStyle())
                .controlSize(.small)
                .disabled(model.performance.isBatteryEnergyLoading || model.performance.isEnergyModeLoading)
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
                energyModeControlCard(model.performance.energyModeSettings)

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
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 320, alignment: .topLeading)
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

    private func energyModeControlCard(_ settings: MacEnergyModeSettings?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                performanceCardTitle(t("Energy Mode", "Energy Mode"), icon: "leaf", tint: .green)
                Spacer(minLength: 8)
                if model.performance.isEnergyModeLoading || model.performance.isEnergyModeApplying {
                    ProgressView()
                        .controlSize(.small)
                }
                if let source = settings?.currentPowerSource {
                    StatusChip(title: "\(t("Сейчас", "Now")): \(energyPowerSourceTitle(source))", tint: .blue)
                }
            }

            Text(t(
                "Выбери отдельный режим macOS для работы от батареи и от зарядки. DRay применяет системный pmset powermode, а не внутренний профиль.",
                "Choose separate macOS modes for battery and power adapter. DRay applies the system pmset powermode, not an internal profile."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            if let settings {
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    energyModeSourceRow(source: .battery, settings: settings)
                    energyModeSourceRow(source: .charger, settings: settings)
                }

                if let error = settings.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(t("Считываем режимы энергопотребления macOS...", "Loading macOS energy modes..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private func energyModeSourceRow(source: MacEnergyPowerSource, settings: MacEnergyModeSettings) -> some View {
        let currentMode = settings.mode(for: source) ?? .automatic
        let modes = availableEnergyModes(for: source, settings: settings, currentMode: currentMode)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DRayIconBadge(
                    icon: source == .battery ? "battery.75percent" : "powerplug",
                    tint: source == .battery ? .green : .blue,
                    size: 24
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(energyPowerSourceTitle(source))
                        .font(.caption.weight(.semibold))
                    Text(energyModeDescription(currentMode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                StatusChip(title: energyModeTitle(currentMode), tint: energyModeTint(currentMode))
            }

            Picker("", selection: Binding(
                get: { currentMode },
                set: { newMode in
                    guard newMode != currentMode else { return }
                    model.setEnergyMode(newMode, for: source)
                }
            )) {
                ForEach(modes) { mode in
                    Text(energyModeTitle(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .disabled(model.performance.isEnergyModeApplying || model.performance.isEnergyModeLoading || modes.count <= 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .calmGlass(.nestedCard, cornerRadius: 14)
    }

    private func availableEnergyModes(
        for source: MacEnergyPowerSource,
        settings: MacEnergyModeSettings,
        currentMode: MacEnergyMode
    ) -> [MacEnergyMode] {
        var modes: [MacEnergyMode] = [.automatic]
        if settings.supportsLowPowerMode {
            modes.append(.lowPower)
        }
        if source == .charger, settings.supportsHighPowerMode {
            modes.append(.highPower)
        }
        if !modes.contains(currentMode) {
            modes.append(currentMode)
        }
        return modes
    }
}
