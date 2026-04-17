import SwiftUI
import AppKit

struct PerformanceView: View {
    @StateObject private var model: PerformanceViewModel
    @StateObject private var monitor = LiveSystemMetricsMonitor()

    @State private var selectedPaths = Set<String>()
    @State private var showCleanupConfirm = false
    @State private var pendingReliefAction: ReliefAction?
    @State private var showReliefConfirm = false
    @State private var reliefResultMessage: String?
    @State private var workspaceTab: PerformanceWorkspaceTab = .overview

    @State private var cpuTrend: [Double] = []
    @State private var memoryTrend: [Double] = []
    @State private var networkHistory: [NetworkHistoryPoint] = []

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: PerformanceViewModel(root: rootModel))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                header
                globalCommandStrip
                workspaceNavigation
                workspaceContent
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.10, shadowOpacity: 0.05, padding: 12)
            }
            .padding(.top, 6)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            t("Отключить выбранные элементы автозапуска?", "Disable selected startup entries?"),
            isPresented: $showCleanupConfirm,
            titleVisibility: .visible
        ) {
            Button(t("Переместить в корзину", "Move to Trash"), role: .destructive) {
                model.cleanupStartupEntries(selectedEntries)
                selectedPaths.removeAll()
            }
            Button(t("Отмена", "Cancel"), role: .cancel) {}
        } message: {
            Text(t(
                "Выбранные элементы автозапуска будут перемещены в корзину.",
                "Selected startup entries will be moved to Trash."
            ))
        }
        .confirmationDialog(
            reliefDialogTitle,
            isPresented: $showReliefConfirm,
            titleVisibility: .visible
        ) {
            Button(reliefActionTitle) {
                executeReliefAction()
            }
            Button(t("Отмена", "Cancel"), role: .cancel) {
                pendingReliefAction = nil
            }
        }
        .alert(t("Изменение нагрузки", "Live Load Adjustment"), isPresented: Binding(
            get: { reliefResultMessage != nil },
            set: { if !$0 { reliefResultMessage = nil } }
        )) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(reliefResultMessage ?? "")
        }
        .onAppear {
            monitor.start()
            if model.performance.report == nil {
                model.runPerformanceScan()
            }
            if model.performance.batteryEnergyReport == nil {
                model.loadBatteryEnergyReport()
            }
        }
        .onDisappear {
            monitor.stop()
        }
        .onReceive(monitor.$snapshot) { snapshot in
            appendTrend(value: snapshot.cpuLoadPercent, to: &cpuTrend)
            appendTrend(value: snapshot.memoryPressurePercent, to: &memoryTrend)
        }
        .onChange(of: model.performance.networkSpeedTestResult?.measuredAt) {
            guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return }
            appendNetworkHistory(result)
        }
        .onChange(of: model.performance.report?.generatedAt) {
            let valid = Set(startupEntries.map { $0.url.path })
            selectedPaths = selectedPaths.intersection(valid)
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: t("Производительность", "Performance"),
            subtitle: t(
                "Командный центр диагностики: нагрузка, батарея, автозапуск и сеть.",
                "Diagnostics command center: load, battery, startup and network."
            )
        ) {
            EmptyView()
        }
    }

    private var globalCommandStrip: some View {
        HStack(spacing: 8) {
            Button(t("Запустить диагностику", "Run Diagnostics")) {
                model.runPerformanceScan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.performance.isScanRunning)

            Button(t("Экспорт лога", "Export Ops Log")) {
                if let url = model.exportOperationLogReport() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(t("Показать crash log", "Reveal Crash Log")) {
                model.revealCrashTelemetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 10)

            if model.performance.isScanRunning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(t("Диагностика выполняется", "Diagnostics running"))
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.08, shadowOpacity: 0.03, padding: 0)
    }

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text(t("Обзор", "Overview")).tag(PerformanceWorkspaceTab.overview)
                Text(t("Нагрузка", "System Load")).tag(PerformanceWorkspaceTab.systemLoad)
                Text(t("Батарея", "Battery & Energy")).tag(PerformanceWorkspaceTab.batteryEnergy)
                Text(t("Автозапуск", "Startup")).tag(PerformanceWorkspaceTab.startup)
                Text(t("Сеть", "Network")).tag(PerformanceWorkspaceTab.network)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var workspaceContent: some View {
        switch workspaceTab {
        case .overview:
            overviewWorkspace
        case .systemLoad:
            systemLoadWorkspace
        case .batteryEnergy:
            batteryEnergyWorkspace
        case .startup:
            startupWorkspace
        case .network:
            networkWorkspace
        }
    }

    private var overviewWorkspace: some View {
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

    private var healthStrip: some View {
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

    private var systemLoadWorkspace: some View {
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

    private var batteryEnergyWorkspace: some View {
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

    private var startupWorkspace: some View {
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

    private var networkWorkspace: some View {
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

    private func batterySummaryStrip(_ snapshot: BatteryEnergySnapshot) -> some View {
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

    private func batteryConsumerRow(_ consumer: EnergyConsumerSnapshot, totalShare: Double) -> some View {
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

    private func startupEntryRow(_ entry: StartupEntry) -> some View {
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

    private func historySparklineCard(title: String, values: [Double], tint: Color) -> some View {
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

    private func metricCard(title: String, value: String, subtitle: String) -> some View {
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

    private func quickActionDeltaPanel(_ delta: QuickActionDeltaReport) -> some View {
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

    private func appendTrend(value: Double, to trend: inout [Double]) {
        trend.append(value)
        if trend.count > 24 {
            trend.removeFirst(trend.count - 24)
        }
    }

    private func appendNetworkHistory(_ result: NetworkSpeedTestResult) {
        let point = NetworkHistoryPoint(
            measuredAt: result.measuredAt,
            downMbps: result.downlinkMbps ?? 0,
            upMbps: result.uplinkMbps ?? 0,
            responsivenessMs: result.responsivenessMs ?? 0
        )

        if let last = networkHistory.last,
           Calendar.current.isDate(last.measuredAt, equalTo: point.measuredAt, toGranularity: .second) {
            return
        }

        networkHistory.append(point)
        if networkHistory.count > 8 {
            networkHistory.removeFirst(networkHistory.count - 8)
        }
    }

    private func requestStartupCleanup() {
        guard !selectedEntries.isEmpty else { return }
        if model.confirmBeforeStartupCleanup {
            showCleanupConfirm = true
            return
        }
        model.cleanupStartupEntries(selectedEntries)
        selectedPaths.removeAll()
    }

    private var rankedLiveConsumers: [LiveConsumerRow] {
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

    private func rankedContribution(for consumer: LiveConsumerRow, in ranked: [LiveConsumerRow]) -> Double {
        let cpuTotal = max(ranked.reduce(0.0) { $0 + $1.cpuPercent }, 0.1)
        let memTotal = max(ranked.reduce(0.0) { $0 + $1.memoryMB }, 0.1)
        let cpuShare = (consumer.cpuPercent / cpuTotal) * 100
        let memShare = (consumer.memoryMB / memTotal) * 100
        return min(100, max(0, (cpuShare * 0.65) + (memShare * 0.35)))
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

    private var startupEntries: [StartupEntry] {
        model.performance.report?.startupEntries ?? []
    }

    private var selectedEntries: [StartupEntry] {
        startupEntries.filter { selectedPaths.contains($0.url.path) }
    }

    private var startupTotalBytes: Int64 {
        startupEntries.reduce(0) { $0 + $1.sizeInBytes }
    }

    private var maxStartupEntrySize: Int64 {
        startupEntries.map(\.sizeInBytes).max() ?? 1
    }

    private var startupReviewCount: Int {
        startupEntries.filter { startupImpactLevel(for: $0) != .low }.count
    }

    private var startupBurdenValue: Double {
        let countScore = min(100.0, Double(startupEntries.count) * 2.4)
        let sizeScore = min(100.0, Double(startupTotalBytes) / Double(80 * 1_048_576))
        return min(100, (countScore * 0.55) + (sizeScore * 0.45))
    }

    private var startupImpactDistribution: (low: Double, review: Double, high: Double) {
        guard !startupEntries.isEmpty else { return (0, 0, 0) }
        let low = Double(startupEntries.filter { startupImpactLevel(for: $0) == .low }.count)
        let review = Double(startupEntries.filter { startupImpactLevel(for: $0) == .review }.count)
        let high = Double(startupEntries.filter { startupImpactLevel(for: $0) == .high }.count)
        let total = max(low + review + high, 1)
        return ((low / total) * 100, (review / total) * 100, (high / total) * 100)
    }

    private func startupImpactLevel(for entry: StartupEntry) -> StartupImpact {
        if entry.sizeInBytes >= 100 * 1_048_576 {
            return .high
        }
        if entry.sizeInBytes >= 25 * 1_048_576 {
            return .review
        }
        return .low
    }

    private var networkStatusChip: (title: String, tint: Color)? {
        guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return nil }
        return (
            title: "\(t("Сеть", "Network")): \(networkQualityTag(from: result))",
            tint: networkQualityColor(from: result)
        )
    }

    private var networkQualityValue: Double? {
        guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return nil }
        let resp = max(1, result.responsivenessMs ?? 140)
        let down = result.downlinkMbps ?? 0
        let up = result.uplinkMbps ?? 0
        let respPenalty = min(100.0, (resp / 220.0) * 100.0)
        let throughputBonus = min(30.0, (down + up) / 12.0)
        return max(0, min(100, respPenalty + 20 - throughputBonus))
    }

    private var networkQualityLabel: String {
        guard let result = model.performance.networkSpeedTestResult, result.isSuccess else {
            return t("Сетевых данных пока нет", "No network data yet")
        }
        return networkQualityText(from: result)
    }

    private var networkInterpretation: String {
        guard let result = model.performance.networkSpeedTestResult else {
            return t(
                "Запусти тест, чтобы получить интерпретацию пропускной способности и отклика.",
                "Run a test to get throughput and responsiveness interpretation."
            )
        }
        if let error = result.errorMessage {
            return t("Тест завершился ошибкой: \(error)", "Test failed: \(error)")
        }
        return networkQualityText(from: result)
    }

    private func networkQualityTag(from result: NetworkSpeedTestResult) -> String {
        let resp = result.responsivenessMs ?? 999
        let down = result.downlinkMbps ?? 0
        if resp <= 45 && down >= 120 { return t("Отлично", "Excellent") }
        if resp <= 90 && down >= 40 { return t("Хорошо", "Good") }
        if resp <= 150 { return t("Умеренно", "Fair") }
        return t("Слабый отклик", "Poor latency")
    }

    private func networkQualityColor(from result: NetworkSpeedTestResult) -> Color {
        let tag = networkQualityTag(from: result)
        switch tag {
        case t("Отлично", "Excellent"): return .green
        case t("Хорошо", "Good"): return .blue
        case t("Умеренно", "Fair"): return .orange
        default: return .red
        }
    }

    private func networkQualityText(from result: NetworkSpeedTestResult) -> String {
        let down = result.downlinkMbps ?? 0
        let up = result.uplinkMbps ?? 0
        let resp = result.responsivenessMs ?? 999
        if resp <= 45 && down >= 120 {
            return t(
                "Сильная пропускная способность и высокий отклик. Подходит для latency-sensitive задач.",
                "Strong throughput and responsiveness. Suitable for latency-sensitive work."
            )
        }
        if resp <= 90 && down >= 40 {
            return t(
                "Стабильное качество сети: хороший баланс скорости и отклика.",
                "Stable network quality: good balance of throughput and responsiveness."
            )
        }
        if resp <= 150 {
            return t(
                "Пропускная способность приемлемая, но отклик средний. Для интерактивных задач может ощущаться задержка.",
                "Throughput is acceptable, but responsiveness is moderate. Interactive tasks may feel delayed."
            )
        }
        if down + up < 20 {
            return t(
                "Низкая пропускная способность и слабый отклик. Стоит проверить сеть перед тяжелыми задачами.",
                "Low throughput and poor responsiveness. Check your connection before heavy tasks."
            )
        }
        return t(
            "Отклик сети неидеален для чувствительных сценариев. Для загрузок подходит лучше, чем для интерактивной работы.",
            "Network responsiveness is not ideal for latency-sensitive scenarios. Better for bulk transfer than interactive work."
        )
    }

    private var batteryHealthLabel: String {
        guard let health = model.performance.batteryEnergyReport?.battery.healthPercent else {
            return t("Нет данных", "No data")
        }
        if health >= 88 { return t("Хорошо", "Good") }
        if health >= 75 { return t("Умеренно", "Fair") }
        return t("Внимание", "Attention")
    }

    private var batteryHealthColor: Color {
        guard let health = model.performance.batteryEnergyReport?.battery.healthPercent else {
            return .secondary
        }
        if health >= 88 { return .green }
        if health >= 75 { return .orange }
        return .red
    }

    private func severityLabel(for value: Double) -> String {
        switch value {
        case 0..<45: return t("Низко", "Low")
        case 45..<75: return t("Умеренно", "Moderate")
        default: return t("Высоко", "High")
        }
    }

    private func severityColor(for value: Double) -> Color {
        switch value {
        case 0..<45: return .green
        case 45..<75: return .orange
        default: return .red
        }
    }

    private var topCPUConsumerName: String {
        guard let top = monitor.snapshot.topCPUConsumers.first else { return "n/a" }
        return shortConsumerName(top.name)
    }

    private var topCPUConsumerValue: String {
        guard let top = monitor.snapshot.topCPUConsumers.first else { return t("Нет данных", "No data") }
        return "CPU \(Int(top.cpuPercent))% · \(Int(top.memoryMB)) MB"
    }

    private var topMemoryConsumerName: String {
        guard let top = monitor.snapshot.topMemoryConsumers.first else { return "n/a" }
        return shortConsumerName(top.name)
    }

    private var topMemoryConsumerValue: String {
        guard let top = monitor.snapshot.topMemoryConsumers.first else { return t("Нет данных", "No data") }
        return "MEM \(Int(top.memoryMB)) MB · CPU \(Int(top.cpuPercent))%"
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
            return t("Снизить нагрузку CPU (понизить приоритет тяжёлых приложений)?", "Reduce CPU load by deprioritizing heavy apps?")
        case .memory:
            return t("Снизить нагрузку памяти (понизить приоритет тяжёлых приложений)?", "Reduce memory pressure by deprioritizing heavy apps?")
        case .none:
            return t("Изменить live-нагрузку?", "Adjust live load?")
        }
    }

    private var reliefActionTitle: String {
        switch pendingReliefAction {
        case .cpu: return t("Понизить приоритет CPU-лидеров", "Lower Priority for Top CPU Apps")
        case .memory: return t("Понизить приоритет memory-лидеров", "Lower Priority for Top Memory Apps")
        case .none: return t("Выполнить", "Run")
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
        reliefResultMessage = t(
            "Изменено \(adjustedText)\nОшибки \(failedText)\nПропущено \(skippedText)",
            "Adjusted \(adjustedText)\nFailed \(failedText)\nSkipped \(skippedText)"
        )
    }

    private func handleRecommendationAction(_ action: PerformanceRecommendationAction) {
        switch action {
        case .selectAllStartup:
            selectedPaths = Set(startupEntries.map { $0.url.path })
            workspaceTab = .startup
        case .selectHeavyStartup:
            selectedPaths = Set(startupEntries.filter { $0.sizeInBytes >= 100 * 1_048_576 }.map { $0.url.path })
            workspaceTab = .startup
        case .openSmartCare:
            model.openSection(.smartCare)
            model.runSmartScan()
        case .runDiagnostics:
            model.runPerformanceScan()
        case .none:
            break
        }
    }

    private func optionalPercent(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)%"
    }

    private func optionalWatts(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f W", value)
    }

    private func optionalTemperature(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f °C", value)
    }

    private func optionalVolts(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f", value)
    }

    private func optionalAmps(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f", value)
    }

    private func optionalMbps(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f Mbps", value)
    }

    private func optionalMilliseconds(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f ms", value)
    }

    private func batteryStateText(_ snapshot: BatteryEnergySnapshot) -> String {
        guard let isCharging = snapshot.isCharging else {
            return t("Статус n/a", "Status n/a")
        }
        return isCharging ? t("Заряжается", "Charging") : t("Разряжается", "Discharging")
    }

    private func timeEstimateText(_ snapshot: BatteryEnergySnapshot) -> String {
        if snapshot.isCharging == true {
            guard let minutes = snapshot.minutesToFull else { return t("До 100% n/a", "To full n/a") }
            let hours = minutes / 60
            let mins = minutes % 60
            return t("До 100% \(hours)ч \(mins)м", "To full \(hours)h \(mins)m")
        }
        guard let minutes = snapshot.minutesToEmpty else { return t("До разрядки n/a", "To empty n/a") }
        let hours = minutes / 60
        let mins = minutes % 60
        return t("До разрядки \(hours)ч \(mins)м", "To empty \(hours)h \(mins)m")
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension PerformanceView {
    var isRussian: Bool { model.appLanguage.localeCode.lowercased().hasPrefix("ru") }

    func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }
}

private enum ReliefAction {
    case cpu
    case memory
}

private enum PerformanceWorkspaceTab: Hashable {
    case overview
    case systemLoad
    case batteryEnergy
    case startup
    case network
}

private struct LiveConsumerRow: Identifiable {
    let id: String
    let displayName: String
    var cpuPercent: Double
    var memoryMB: Double
    var batteryImpactScore: Double
}

private struct NetworkHistoryPoint: Identifiable {
    let id = UUID()
    let measuredAt: Date
    let downMbps: Double
    let upMbps: Double
    let responsivenessMs: Double
}

private enum StartupImpact {
    case low
    case review
    case high

    var title: String {
        switch self {
        case .low: return "Low"
        case .review: return "Review"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .review: return .orange
        case .high: return .red
        }
    }
}
