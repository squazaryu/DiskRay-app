import SwiftUI

struct OverviewView: View {
    @ObservedObject var rootModel: RootViewModel
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    @Environment(\.drayInterfaceDensity) private var density
    @StateObject private var monitor = LiveSystemMetricsMonitor(updateInterval: 1.2, heavySamplePeriod: 5.0)
    @State private var healthTrend: [Double] = []
    @State private var cpuTrend: [Double] = []
    @State private var memoryTrend: [Double] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: layoutMetrics.sectionSpacing) {
                ModuleHeaderCard(
                    title: t("Обзор", "Overview"),
                    subtitle: t("Состояние Mac и основные действия DRay.", "Your Mac at a glance.")
                ) {
                    HStack(spacing: 8) {
                        Label(deviceName, systemImage: "desktopcomputer")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Button {
                            rootModel.runUnifiedScan()
                        } label: {
                            Label(t("Smart Scan", "Smart Scan"), systemImage: "wand.and.sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                heroCard
                metricGrid

                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    recommendationsCard
                    topConsumersCard
                    activityCard
                }

                DRayBottomStatusStrip(items: bottomStatusItems)
            }
            .padding(layoutMetrics.cardSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            monitor.start()
        }
        .onDisappear {
            monitor.stop()
        }
        .onReceive(monitor.$snapshot) { snapshot in
            appendTrend(healthScore * 100, to: &healthTrend, limit: 32)
            appendTrend(snapshot.cpuLoadPercent, to: &cpuTrend, limit: 32)
            appendTrend(snapshot.memoryPressurePercent, to: &memoryTrend, limit: 32)
        }
    }

    private var heroCard: some View {
        HStack(spacing: density == .compact ? 14 : 20) {
            DRayLiquidStatusRing(icon: healthIcon, tint: healthColor, size: density == .compact ? 102 : 120)

            VStack(alignment: .leading, spacing: density == .compact ? 6 : 8) {
                Text(t("СОСТОЯНИЕ СИСТЕМЫ", "SYSTEM HEALTH"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(healthColor)
                Text(healthTitle)
                    .font(.system(size: density == .compact ? 30 : 34, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(healthSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Button {
                        rootModel.openSection(.smartCare)
                    } label: {
                        Label(t("Открыть Smart Care", "Open Smart Care"), systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        rootModel.openSection(focusSection)
                    } label: {
                        Label(focusActionTitle, systemImage: focusIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: density == .compact ? 320 : 360, alignment: .leading)

            Spacer(minLength: density == .compact ? 10 : 16)

            VStack(alignment: .leading, spacing: density == .compact ? 7 : 10) {
                DRaySparklineView(values: healthTrend, tint: healthColor, lineWidth: 2.1)
                    .frame(height: density == .compact ? 52 : 68)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 18) {
                            ForEach(0..<4, id: \.self) { _ in
                                Divider().opacity(0.16)
                            }
                        }
                    }
                HStack {
                    Text(t("Тренд здоровья", "Health Trend"))
                    Spacer()
                    Text("Now \(Int(healthScore * 100))/100")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if density == .compact {
                    compactHealthFormulaCard
                } else {
                    healthFormulaCard
                }
            }
            .frame(width: density == .compact ? 300 : 340)
        }
        .padding(layoutMetrics.cardSpacing + 2)
        .glassSurface(cornerRadius: 22, strokeOpacity: 0.12, shadowOpacity: 0.10, padding: 0)
    }

    private var metricGrid: some View {
        HStack(spacing: layoutMetrics.cardSpacing) {
            DRayDashboardMetricTile(
                title: t("Хранилище", "Storage"),
                value: usedStorageText,
                subtitle: totalStorageText,
                icon: "internaldrive",
                tint: .blue,
                progress: diskUsedRatio,
                action: { rootModel.openSection(.spaceLens) }
            )
            DRayDashboardMetricTile(
                title: t("Память", "Memory"),
                value: memoryUsedText,
                subtitle: memoryTotalText,
                icon: "memorychip",
                tint: .purple,
                progress: memoryUsedRatio,
                sparkline: memoryTrend,
                action: { rootModel.openSection(.performance) }
            )
            DRayDashboardMetricTile(
                title: t("Батарея", "Battery"),
                value: batteryValueText,
                subtitle: batterySubtitle,
                icon: "battery.75percent",
                tint: .green,
                progress: batteryProgress,
                action: { rootModel.openSection(.performance) }
            )
            DRayDashboardMetricTile(
                title: "CPU",
                value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                subtitle: t("текущая нагрузка", "current load"),
                icon: "waveform.path.ecg",
                tint: .orange,
                progress: min(1, monitor.snapshot.cpuLoadPercent / 100),
                sparkline: cpuTrend,
                action: { rootModel.openSection(.performance) }
            )
        }
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: t("Рекомендации", "Recommendations"), action: t("Все", "View All")) {
                rootModel.openSection(.smartCare)
            }

            ForEach(recommendations) { item in
                overviewActionRow(item)
            }
        }
        .frame(maxWidth: .infinity, minHeight: density == .compact ? 180 : 220, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var topConsumersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: t("Главные потребители", "Top Consumers"), action: t("Performance", "Performance")) {
                rootModel.openSection(.performance)
            }

            if topConsumers.isEmpty {
                Text(t("Собираем live-метрики процессов...", "Collecting live process telemetry..."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topConsumers.enumerated()), id: \.element.id) { index, consumer in
                        consumerRow(consumer, rank: index + 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: density == .compact ? 180 : 220, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: t("Активность", "Activity"), action: t("Recovery", "Recovery")) {
                rootModel.openSection(.recovery)
            }

            overviewActionRow(
                OverviewRecommendation(
                    title: t("Smart Care", "Smart Care"),
                    subtitle: smartCareActivityText,
                    icon: "sparkles",
                    tint: .blue,
                    actionTitle: t("Открыть", "Open"),
                    section: .smartCare
                )
            )
            overviewActionRow(
                OverviewRecommendation(
                    title: t("Восстановление", "Recovery"),
                    subtitle: recoveryActivityText,
                    icon: "arrow.uturn.backward.circle",
                    tint: .green,
                    actionTitle: t("Открыть", "Open"),
                    section: .recovery
                )
            )
            overviewActionRow(
                OverviewRecommendation(
                    title: t("Производительность", "Performance"),
                    subtitle: performanceActivityText,
                    icon: "waveform.path.ecg",
                    tint: .cyan,
                    actionTitle: t("Открыть", "Open"),
                    section: .performance
                )
            )
        }
        .frame(maxWidth: .infinity, minHeight: density == .compact ? 180 : 220, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private func cardHeader(title: String, action: String, onAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button(action, action: onAction)
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(drayAccentColor)
        }
    }

    private func overviewActionRow(_ item: OverviewRecommendation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.tint)
                .frame(width: 30, height: 30)
                .background(item.tint.opacity(colorScheme == .dark ? 0.18 : 0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(item.actionTitle) {
                rootModel.openSection(item.section)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func consumerRow(_ consumer: ProcessConsumer, rank: Int) -> some View {
        DRayRankedBarRow(
            rank: rank,
            title: consumer.name,
            subtitle: "MEM \(Int(consumer.memoryMB))MB · EI \(String(format: "%.1f", consumer.batteryImpactScore))",
            value: "\(Int(consumer.cpuPercent))%",
            progress: min(1, consumer.cpuPercent / max(100, maxTopCPU)),
            tint: .blue,
            icon: "app.fill"
        )
    }

    private var healthFormulaCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Как считается", "How it is calculated"))
                .font(.caption.weight(.semibold))
            healthFactorRow(title: "CPU", value: monitor.snapshot.cpuLoadPercent / 100, tint: .orange)
            healthFactorRow(title: t("Память", "Memory"), value: monitor.snapshot.memoryPressurePercent / 100, tint: .purple)
            healthFactorRow(title: t("Хранилище", "Storage"), value: diskUsedRatio, tint: .blue)
            healthFactorRow(
                title: t("Доступ", "Access"),
                value: rootModel.permissions.hasFullDiskAccess ? 0.0 : 1.0,
                tint: rootModel.permissions.hasFullDiskAccess ? .green : .orange
            )
            Text(t(
                "Индекс учитывает live CPU, давление памяти, заполнение диска и доступ DRay.",
                "The index combines live CPU, memory pressure, storage pressure and DRay access."
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var compactHealthFormulaCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(t("Индекс", "Index"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("CPU · MEM · DISK · ACCESS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            DRayProgressBar(value: 1 - healthScore, tint: healthColor, height: 4)
            Text(t(
                "Показывает текущую нагрузку, память, диск и доступ.",
                "Combines current load, memory, disk and access."
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func healthFactorRow(title: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            DRayProgressBar(value: value, tint: tint, height: 4)
            Text("\(Int(min(1, max(0, value)) * 100))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 26, alignment: .trailing)
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drayAccentColor) private var drayAccentColor

    private var isRussian: Bool {
        rootModel.appLanguage.localeCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    private func appendTrend(_ value: Double, to series: inout [Double], limit: Int) {
        guard value.isFinite else { return }
        series.append(value)
        if series.count > limit {
            series.removeFirst(series.count - limit)
        }
    }

    private var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    private var diskUsedRatio: Double {
        guard monitor.snapshot.diskTotalBytes > 0 else { return 0 }
        return Double(max(0, monitor.snapshot.diskTotalBytes - monitor.snapshot.diskFreeBytes)) / Double(monitor.snapshot.diskTotalBytes)
    }

    private var memoryUsedRatio: Double {
        guard monitor.snapshot.memoryTotalBytes > 0 else { return 0 }
        return Double(monitor.snapshot.memoryUsedBytes) / Double(monitor.snapshot.memoryTotalBytes)
    }

    private var batteryProgress: Double? {
        monitor.snapshot.batteryLevelPercent.map { Double($0) / 100.0 }
    }

    private var healthScore: Double {
        let cpuPenalty = min(0.24, monitor.snapshot.cpuLoadPercent / 100 * 0.24)
        let memoryPenalty = min(0.26, monitor.snapshot.memoryPressurePercent / 100 * 0.26)
        let diskPenalty = diskUsedRatio > 0.86 ? 0.18 : diskUsedRatio > 0.74 ? 0.09 : 0
        let permissionPenalty = rootModel.permissions.hasFullDiskAccess ? 0 : 0.12
        return max(0.08, min(1, 1 - cpuPenalty - memoryPenalty - diskPenalty - permissionPenalty))
    }

    private var healthTitle: String {
        if healthScore >= 0.76 { return t("Отлично", "Excellent") }
        if healthScore >= 0.54 { return t("Требует внимания", "Needs Attention") }
        return t("Нужно действие", "Action Needed")
    }

    private var healthSubtitle: String {
        if !rootModel.permissions.hasFullDiskAccess {
            return t(
                "Выдай Full Disk Access, чтобы диагностика и очистка были полными.",
                "Grant Full Disk Access for complete diagnostics and cleanup coverage."
            )
        }
        if monitor.snapshot.memoryPressurePercent >= 72 {
            return t("Давление памяти повышено. Проверь Performance.", "Memory pressure is elevated. Review Performance.")
        }
        if diskUsedRatio >= 0.82 {
            return t("Свободного места становится мало. Проверь Space Lens.", "Storage is getting tight. Review Space Lens.")
        }
        return t("Mac в хорошем состоянии. Можно запустить Smart Scan для свежей проверки.", "Your Mac is in good shape. Run Smart Scan for a fresh check.")
    }

    private var healthIcon: String {
        healthScore >= 0.54 ? "checkmark" : "exclamationmark"
    }

    private var healthColor: Color {
        if healthScore >= 0.76 { return .blue }
        if healthScore >= 0.54 { return .orange }
        return .red
    }

    private var focusSection: AppSection {
        if !rootModel.permissions.hasFullDiskAccess { return .settings }
        if monitor.snapshot.memoryPressurePercent >= 72 || monitor.snapshot.cpuLoadPercent >= 70 { return .performance }
        if diskUsedRatio >= 0.82 { return .spaceLens }
        return .smartCare
    }

    private var focusIcon: String {
        switch focusSection {
        case .settings: return "gearshape"
        case .performance: return "waveform.path.ecg"
        case .spaceLens: return "internaldrive"
        default: return "sparkles"
        }
    }

    private var focusActionTitle: String {
        switch focusSection {
        case .settings: return t("Настройки", "Settings")
        case .performance: return t("Performance", "Performance")
        case .spaceLens: return "Space Lens"
        default: return "Smart Care"
        }
    }

    private var usedStorageText: String {
        guard monitor.snapshot.diskTotalBytes > 0 else { return "n/a" }
        let used = max(0, monitor.snapshot.diskTotalBytes - monitor.snapshot.diskFreeBytes)
        return ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    }

    private var totalStorageText: String {
        guard monitor.snapshot.diskTotalBytes > 0 else { return t("Нет данных", "Unavailable") }
        return "\(Int(diskUsedRatio * 100))% \(t("использовано", "used"))"
    }

    private var memoryUsedText: String {
        ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory)
    }

    private var memoryTotalText: String {
        "\(Int(monitor.snapshot.memoryPressurePercent))% \(t("давление", "pressure"))"
    }

    private var batteryValueText: String {
        monitor.snapshot.batteryLevelPercent.map { "\($0)%" } ?? "n/a"
    }

    private var batterySubtitle: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else {
            return t("Нет данных", "Unavailable")
        }
        if monitor.snapshot.batteryIsCharging == true {
            return "\(percent)% · \(t("заряжается", "charging"))"
        }
        if let minutes = monitor.snapshot.batteryMinutesRemaining {
            return "\(minutes / 60)h \(minutes % 60)m \(t("осталось", "remaining"))"
        }
        return t("От батареи", "On battery")
    }

    private var startupHealthTitle: String {
        let entries = rootModel.performanceReport?.startupEntries.count ?? 0
        if entries >= 18 { return t("Проверить", "Review") }
        if entries >= 8 { return t("Нормально", "Good") }
        return t("Чисто", "Clean")
    }

    private var startupHealthSubtitle: String {
        let entries = rootModel.performanceReport?.startupEntries.count ?? 0
        return "\(entries) \(t("элементов", "items"))"
    }

    private var startupHealthColor: Color {
        let entries = rootModel.performanceReport?.startupEntries.count ?? 0
        if entries >= 18 { return .orange }
        return .green
    }

    private var startupHealthProgress: Double {
        let entries = rootModel.performanceReport?.startupEntries.count ?? 0
        return min(1, Double(entries) / 24.0)
    }

    private var recommendations: [OverviewRecommendation] {
        var items: [OverviewRecommendation] = []
        if !rootModel.permissions.hasFullDiskAccess {
            items.append(.init(
                title: t("Выдать Full Disk Access", "Enable Full Disk Access"),
                subtitle: t("Расширит покрытие Smart Care, Search и Uninstaller.", "Improves Smart Care, Search and Uninstaller coverage."),
                icon: "lock.shield",
                tint: .orange,
                actionTitle: t("Открыть", "Open"),
                section: .settings
            ))
        }
        if diskUsedRatio >= 0.74 {
            items.append(.init(
                title: t("Проверить хранилище", "Review Storage"),
                subtitle: t("Space Lens покажет крупные папки и кандидаты на очистку.", "Space Lens shows large folders and cleanup candidates."),
                icon: "internaldrive",
                tint: .blue,
                actionTitle: t("Открыть", "Open"),
                section: .spaceLens
            ))
        }
        if monitor.snapshot.memoryPressurePercent >= 65 {
            items.append(.init(
                title: t("Снизить нагрузку", "Reduce Load"),
                subtitle: t("Performance покажет процессы, память и CPU.", "Performance shows processes, memory and CPU pressure."),
                icon: "waveform.path.ecg",
                tint: .purple,
                actionTitle: t("Открыть", "Open"),
                section: .performance
            ))
        }
        items.append(.init(
            title: t("Запустить Smart Care", "Run Smart Care"),
            subtitle: t("Обновить рекомендации по безопасной очистке.", "Refresh safe cleanup recommendations."),
            icon: "sparkles",
            tint: .cyan,
            actionTitle: t("Открыть", "Open"),
            section: .smartCare
        ))
        return Array(items.prefix(3))
    }

    private var topConsumers: [ProcessConsumer] {
        Array(monitor.snapshot.topCPUConsumers.prefix(5))
    }

    private var maxTopCPU: Double {
        max(topConsumers.map(\.cpuPercent).max() ?? 100, 1)
    }

    private var smartCareActivityText: String {
        let count = rootModel.smartCareController.state.categories.count
        return count == 0
            ? t("Нет свежего плана очистки.", "No fresh cleanup plan yet.")
            : "\(count) \(t("категорий готовы к проверке.", "categories ready for review."))"
    }

    private var recoveryActivityText: String {
        let deleted = rootModel.recentlyDeleted.count
        let rollback = rootModel.quickActionRollbackSessions.count
        return "\(deleted) \(t("удалённых", "deleted")) · \(rollback) rollback"
    }

    private var performanceActivityText: String {
        if rootModel.performanceReport == nil {
            return t("Диагностика ещё не запускалась.", "Diagnostics have not run yet.")
        }
        return t("Последний отчёт доступен.", "Latest report is available.")
    }

    private var bottomStatusItems: [DRayBottomStatusStrip.Item] {
        [
            .init(title: t("Uptime", "Uptime"), value: uptimeText, icon: "clock", tint: .blue),
            .init(title: t("Target", "Target"), value: rootModel.selectedTarget.name, icon: "scope", tint: .cyan),
            .init(title: "Full Disk", value: rootModel.permissions.hasFullDiskAccess ? "On" : "Required", icon: "lock.shield", tint: rootModel.permissions.hasFullDiskAccess ? .green : .orange),
            .init(title: t("Network", "Network"), value: networkText, icon: "wifi", tint: .teal)
        ]
    }

    private var uptimeText: String {
        let seconds = Int(monitor.snapshot.uptimeSeconds)
        return "\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h"
    }

    private var networkText: String {
        let down = ByteCountFormatter.string(fromByteCount: Int64(monitor.snapshot.networkDownBytesPerSecond), countStyle: .file)
        let up = ByteCountFormatter.string(fromByteCount: Int64(monitor.snapshot.networkUpBytesPerSecond), countStyle: .file)
        return "↓ \(down)/s  ↑ \(up)/s"
    }
}

private struct OverviewRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let actionTitle: String
    let section: AppSection
}
