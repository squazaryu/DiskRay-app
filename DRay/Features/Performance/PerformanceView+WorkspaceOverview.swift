import SwiftUI

extension PerformanceView {
    var overviewWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            performanceMetricGrid

            HStack(alignment: .top, spacing: 12) {
                startupImpactOverviewCard
                topResourceConsumersCard
                operationalInsightCard
            }

            HStack(alignment: .top, spacing: 12) {
                loadTrendCard
                networkOverviewCard
                quickActionsOverviewCard
            }

            if let delta = model.performanceQuickActionDelta {
                quickActionDeltaPanel(delta)
            }
        }
    }

    private var performanceMetricGrid: some View {
        HStack(spacing: 12) {
            DRayDashboardMetricTile(
                title: "CPU",
                value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                subtitle: "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%",
                icon: "cpu",
                tint: .blue,
                progress: min(1, monitor.snapshot.cpuLoadPercent / 100),
                sparkline: cpuTrend,
                action: { workspaceTab = .systemLoad }
            )
            DRayDashboardMetricTile(
                title: t("Память", "Memory"),
                value: "\(Int(monitor.snapshot.memoryPressurePercent))%",
                subtitle: ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory),
                icon: "memorychip",
                tint: .purple,
                progress: min(1, monitor.snapshot.memoryPressurePercent / 100),
                sparkline: memoryTrend,
                action: { workspaceTab = .systemLoad }
            )
            DRayDashboardMetricTile(
                title: t("Батарея", "Battery"),
                value: monitor.snapshot.batteryLevelPercent.map { "\($0)%" } ?? "n/a",
                subtitle: batteryHealthLabel,
                icon: "battery.75percent",
                tint: batteryHealthColor,
                progress: monitor.snapshot.batteryLevelPercent.map { Double($0) / 100.0 },
                action: { workspaceTab = .batteryEnergy }
            )
            DRayDashboardMetricTile(
                title: t("Автозапуск", "Startup"),
                value: severityLabel(for: startupBurdenValue),
                subtitle: "\(startupEntries.count) \(t("элементов", "items"))",
                icon: "power",
                tint: severityColor(for: startupBurdenValue),
                progress: min(1, startupBurdenValue / 100),
                action: { workspaceTab = .startup }
            )
        }
    }

    private var startupImpactOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(t("Влияние автозапуска", "Startup Impact"), icon: "power", tint: .orange)
            Text(severityLabel(for: startupBurdenValue))
                .font(.title2.weight(.semibold))
                .foregroundStyle(severityColor(for: startupBurdenValue))
            DiagnosticBurdenBar(
                value: startupBurdenValue,
                label: t("Общее бремя", "Overall burden"),
                detail: "\(startupEntries.count) \(t("элементов автозапуска", "startup entries"))"
            )
            HStack(spacing: 10) {
                miniStat(title: t("Всего", "Total"), value: "\(startupEntries.count)", tint: .blue)
                miniStat(title: t("Review", "Review"), value: "\(startupReviewCount)", tint: .orange)
            }
            Button(t("Управлять", "Manage")) { workspaceTab = .startup }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .padding(12)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private var topResourceConsumersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(t("Главные потребители", "Top Resource Consumers"), icon: "app.badge", tint: .blue)
            let ranked = Array(rankedLiveConsumers.prefix(5))
            if ranked.isEmpty {
                Text(t("Собираем live-метрики процессов...", "Collecting live process telemetry..."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 148, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, consumer in
                        DRayRankedBarRow(
                            rank: index + 1,
                            title: consumer.displayName,
                            subtitle: "MEM \(Int(consumer.memoryMB)) MB · EI \(String(format: "%.1f", consumer.batteryImpactScore))",
                            value: "CPU \(Int(consumer.cpuPercent))%",
                            progress: rankedContribution(for: consumer, in: ranked) / 100,
                            tint: .blue,
                            icon: "app.fill"
                        )
                    }
                }
            }
            Button(t("Открыть нагрузку", "Open System Load")) { workspaceTab = .systemLoad }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .padding(12)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private var operationalInsightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(t("Инсайт", "Insight"), icon: "lightbulb", tint: insightTint)
            Text(insightTitle)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Text(insightDetails)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            Spacer(minLength: 0)
            Button(insightActionTitle) { workspaceTab = insightTarget }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .padding(12)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private var loadTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(t("Тренд нагрузки", "System Load"), icon: "waveform.path.ecg", tint: .purple)
            ZStack {
                DRaySparklineView(values: cpuTrend, tint: .blue, lineWidth: 1.8)
                DRaySparklineView(values: memoryTrend, tint: .purple, lineWidth: 1.8)
            }
            .frame(height: 92)
            HStack(spacing: 10) {
                legendDot("CPU", tint: .blue)
                legendDot(t("Память", "Memory"), tint: .purple)
                Spacer()
                Text("Now")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(12)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private var networkOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(t("Сеть", "Network"), icon: "wifi", tint: .teal)
            HStack(spacing: 10) {
                miniStat(title: "Down", value: networkDownText, tint: .blue)
                miniStat(title: "Up", value: networkUpText, tint: .teal)
            }
            DRaySparklineView(values: networkTrendValues, tint: .teal, lineWidth: 1.8)
                .frame(height: 52)
            Button(t("Тест сети", "Run Network Test")) { workspaceTab = .network }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(12)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private var quickActionsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardTitle(t("Быстрые действия", "Quick Actions"), icon: "bolt", tint: .green)
            actionRow(t("Reduce CPU", "Reduce CPU"), icon: "cpu") {
                pendingReliefAction = .cpu
                showReliefConfirm = true
            }
            .disabled(cpuReliefCandidates.isEmpty)
            actionRow(t("Reduce Memory", "Reduce Memory"), icon: "memorychip") {
                pendingReliefAction = .memory
                showReliefConfirm = true
            }
            .disabled(memoryReliefCandidates.isEmpty)
            actionRow(t("Run Diagnostics", "Run Diagnostics"), icon: "stethoscope") {
                model.runPerformanceScan()
            }
            .disabled(model.performance.isScanRunning)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(12)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }

    private func cardTitle(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            DRayIconBadge(icon: icon, tint: tint, size: 28)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func miniStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func legendDot(_ title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                DRayIconBadge(icon: icon, tint: .blue, size: 26)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var insightTint: Color {
        insightSignal.tint
    }

    private var insightTitle: String {
        insightSignal.title
    }

    private var insightDetails: String {
        insightSignal.details
    }

    private var insightActionTitle: String {
        insightSignal.actionTitle
    }

    private var insightTarget: PerformanceWorkspaceTab {
        insightSignal.target
    }

    private var insightSignal: (title: String, details: String, actionTitle: String, target: PerformanceWorkspaceTab, tint: Color) {
        if monitor.snapshot.memoryPressurePercent >= 75 {
            return (
                t("Память давит на систему", "Memory pressure is elevated"),
                t(
                    "Закрой тяжёлые приложения или снизь приоритет memory-лидеров, чтобы вернуть отзывчивость.",
                    "Close memory-heavy apps or reduce priority for memory leaders to improve responsiveness."
                ),
                t("Открыть нагрузку", "Open System Load"),
                .systemLoad,
                .purple
            )
        }
        if monitor.snapshot.cpuLoadPercent >= 75 {
            return (
                t("CPU сейчас главный источник нагрузки", "CPU is the main pressure point"),
                t(
                    "Проверь live-потребителей и снизь приоритет процессов, которые создают пик нагрузки.",
                    "Review live consumers and lower priority for processes creating the current load spike."
                ),
                t("Открыть нагрузку", "Open System Load"),
                .systemLoad,
                .blue
            )
        }
        if startupBurdenValue >= 60 {
            return (
                t("Автозапуск стоит пересмотреть", "Startup deserves review"),
                t(
                    "Высокое число или размер login items может замедлять старт и фоновую работу.",
                    "A high number or footprint of login items can slow startup and background work."
                ),
                t("Открыть автозапуск", "Open Startup"),
                .startup,
                .orange
            )
        }
        if let networkQualityValue, networkQualityValue >= 70 {
            return (
                t("Сеть ограничивает интерактивные задачи", "Network may limit interactive work"),
                networkQualityLabel,
                t("Открыть сеть", "Open Network"),
                .network,
                .teal
            )
        }
        if let recommendation = model.performance.report?.recommendations.first {
            return (
                recommendation.title,
                recommendation.details,
                recommendation.actionTitle ?? t("Открыть детали", "Open Details"),
                targetTab(for: recommendation.action),
                .green
            )
        }
        return (
            t("Система выглядит ровно", "System looks balanced"),
            t(
                "Live-нагрузка, батарея и автозапуск не показывают критичных сигналов прямо сейчас.",
                "Live load, battery and startup do not show critical signals right now."
            ),
            t("Запустить диагностику", "Run Diagnostics"),
            .overview,
            .green
        )
    }

    private func targetTab(for action: PerformanceRecommendationAction) -> PerformanceWorkspaceTab {
        switch action {
        case .selectAllStartup, .selectHeavyStartup:
            return .startup
        case .openSmartCare, .runDiagnostics, .none:
            return .overview
        }
    }

    private var networkDownText: String {
        if let result = latestNetworkResult, result.isSuccess {
            return optionalMbps(result.downlinkMbps)
        }
        return ByteCountFormatter.string(
            fromByteCount: Int64(monitor.snapshot.networkDownBytesPerSecond),
            countStyle: .file
        ) + "/s"
    }

    private var networkUpText: String {
        if let result = latestNetworkResult, result.isSuccess {
            return optionalMbps(result.uplinkMbps)
        }
        return ByteCountFormatter.string(
            fromByteCount: Int64(monitor.snapshot.networkUpBytesPerSecond),
            countStyle: .file
        ) + "/s"
    }

    private var networkTrendValues: [Double] {
        if !networkHistory.isEmpty {
            return networkHistory.map { $0.downMbps + $0.upMbps }
        }
        return [
            monitor.snapshot.networkDownBytesPerSecond + monitor.snapshot.networkUpBytesPerSecond
        ]
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
