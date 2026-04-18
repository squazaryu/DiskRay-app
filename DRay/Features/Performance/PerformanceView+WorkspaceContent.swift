import SwiftUI
import AppKit

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

    var startupWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("Startup Diagnostics", "Startup Diagnostics"))
                    .font(.headline)
                Spacer()
                Button(t("Отключить выбранные", "Disable Selected")) {
                    requestStartupCleanup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selectedEntries.isEmpty)

                Button(t("Выбрать heavy", "Select Heavy")) {
                    selectedPaths = Set(startupEntries.filter { startupImpactLevel(for: $0) == .high }.map { $0.url.path })
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(startupEntries.isEmpty)

                Button(t("Сбросить", "Clear")) {
                    selectedPaths.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedPaths.isEmpty)
            }

            HStack(spacing: 10) {
                metricCard(
                    title: t("Записи", "Entries"),
                    value: "\(startupEntries.count)",
                    subtitle: t("Всего элементов автозапуска", "Total startup entries")
                )
                metricCard(
                    title: t("К review", "Review"),
                    value: "\(startupReviewCount)",
                    subtitle: t("Требуют внимания", "Need attention")
                )
                metricCard(
                    title: t("Footprint", "Footprint"),
                    value: ByteCountFormatter.string(fromByteCount: startupTotalBytes, countStyle: .file),
                    subtitle: t("Общий размер", "Total size")
                )
                metricCard(
                    title: t("Burden", "Burden"),
                    value: severityLabel(for: startupBurdenValue),
                    subtitle: t("Оценка влияния на запуск", "Launch impact estimate")
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                DiagnosticBurdenBar(
                    value: startupBurdenValue,
                    label: t("Burden Scale", "Burden Scale"),
                    detail: t("Комбинирует количество и размер startup-компонентов", "Combines count and footprint of startup components")
                )

                HStack(spacing: 8) {
                    RankedShareBar(
                        title: t("Low", "Low"),
                        subtitle: t("Низкий impact", "Low impact"),
                        percentage: startupImpactDistribution.low,
                        accent: .green
                    )
                    RankedShareBar(
                        title: t("Review", "Review"),
                        subtitle: t("Проверить вручную", "Manual review"),
                        percentage: startupImpactDistribution.review,
                        accent: .orange
                    )
                    RankedShareBar(
                        title: t("High", "High"),
                        subtitle: t("Высокий impact", "High impact"),
                        percentage: startupImpactDistribution.high,
                        accent: .red
                    )
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Ranked Startup Items", "Ranked Startup Items"))
                    .font(.subheadline.weight(.semibold))

                if startupEntries.isEmpty {
                    Text(t("Автозапуск не обнаружен. Запусти диагностику.", "No startup entries detected. Run diagnostics."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(startupEntries.prefix(14)) { entry in
                        startupEntryRow(entry)
                    }
                }
            }
        }
    }

    var networkWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("Network Diagnostics", "Network Diagnostics"))
                    .font(.headline)
                Spacer()
                Button(t("Запустить тест", "Run Test")) {
                    model.runNetworkSpeedTest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.performance.isNetworkSpeedTestRunning)
            }

            if model.performance.isNetworkSpeedTestRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t(
                        "Измеряем скорость (может занять до 10–15 секунд)...",
                        "Measuring network speed (can take up to 10–15 seconds)..."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            HStack(spacing: 10) {
                metricCard(
                    title: t("Скачивание", "Download"),
                    value: optionalMbps(model.performance.networkSpeedTestResult?.downlinkMbps),
                    subtitle: t("Пропускная способность вниз", "Downlink throughput")
                )
                metricCard(
                    title: t("Отдача", "Upload"),
                    value: optionalMbps(model.performance.networkSpeedTestResult?.uplinkMbps),
                    subtitle: t("Пропускная способность вверх", "Uplink throughput")
                )
                metricCard(
                    title: t("Отклик", "Responsiveness"),
                    value: optionalMilliseconds(model.performance.networkSpeedTestResult?.responsivenessMs),
                    subtitle: t("Влияет на интерактивность", "Impacts interactive tasks")
                )
                metricCard(
                    title: "Base RTT",
                    value: optionalMilliseconds(model.performance.networkSpeedTestResult?.baseRTTMs),
                    subtitle: t("Базовая задержка сети", "Baseline network latency")
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Качество", "Quality"))
                    .font(.subheadline.weight(.semibold))
                Text(networkInterpretation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let last = model.performance.networkSpeedTestResult {
                    Text(t(
                        "Последнее измерение: \(relativeTime(last.measuredAt))",
                        "Last measurement: \(relativeTime(last.measuredAt))"
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !networkHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Recent Session History", "Recent Session History"))
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        historySparklineCard(
                            title: t("Скачивание", "Download"),
                            values: networkHistory.map { $0.downMbps },
                            tint: .blue
                        )
                        historySparklineCard(
                            title: t("Отдача", "Upload"),
                            values: networkHistory.map { $0.upMbps },
                            tint: .green
                        )
                        historySparklineCard(
                            title: t("Отклик", "Responsiveness"),
                            values: networkHistory.map { $0.responsivenessMs },
                            tint: .orange
                        )
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let error = model.performance.networkSpeedTestResult?.errorMessage {
                Text(t("Тест не выполнен: \(error)", "Speed test failed: \(error)"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
}
}
