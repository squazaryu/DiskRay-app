import SwiftUI

struct OverviewView: View {
    @ObservedObject var rootModel: RootViewModel
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    @Environment(\.drayInterfaceDensity) private var density
    @StateObject private var monitor = LiveSystemMetricsMonitor(updateInterval: 1.2, heavySamplePeriod: 5.0)

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
                        .buttonStyle(DRayPrimaryButtonStyle())
                        .controlSize(.small)
                    }
                }

                heroCard
                metricGrid

                overviewInsightsLayout

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
    }

    private var heroCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: density == .compact ? 14 : 20) {
                heroStatusBlock
                Spacer(minLength: density == .compact ? 10 : 16)
                heroTrendBlock
                    .frame(maxWidth: density == .compact ? 300 : 340, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: density == .compact ? 12 : 14) {
                heroStatusBlock
                heroTrendBlock
            }
        }
        .padding(max(10, layoutMetrics.cardSpacing))
        .calmGlass(.section, cornerRadius: 18)
    }

    private var metricGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                metricTiles(minWidth: 190)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(minimum: 210), spacing: layoutMetrics.cardSpacing), GridItem(.flexible(minimum: 210), spacing: layoutMetrics.cardSpacing)],
                alignment: .leading,
                spacing: layoutMetrics.cardSpacing
            ) {
                metricTiles()
            }

            LazyVGrid(
                columns: [GridItem(.flexible(minimum: 190), spacing: layoutMetrics.cardSpacing)],
                alignment: .leading,
                spacing: layoutMetrics.cardSpacing
            ) {
                metricTiles()
            }
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .calmGlass(.card, cornerRadius: 16)
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
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topConsumers.prefix(4).enumerated()), id: \.element.id) { index, consumer in
                        consumerRow(consumer, rank: index + 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .calmGlass(.card, cornerRadius: 16)
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
                    tint: .teal,
                    actionTitle: t("Открыть", "Open"),
                    section: .performance
                )
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .calmGlass(.card, cornerRadius: 16)
    }

    private var overviewInsightsLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                recommendationsCard
                    .frame(minWidth: 320)
                topConsumersCard
                    .frame(minWidth: 320)
                activityCard
                    .frame(minWidth: 320)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(minimum: 300), spacing: layoutMetrics.cardSpacing), GridItem(.flexible(minimum: 300), spacing: layoutMetrics.cardSpacing)],
                alignment: .leading,
                spacing: layoutMetrics.cardSpacing
            ) {
                recommendationsCard
                topConsumersCard
                activityCard
                    .gridCellColumns(2)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(minimum: 260), spacing: layoutMetrics.cardSpacing)],
                alignment: .leading,
                spacing: layoutMetrics.cardSpacing
            ) {
                recommendationsCard
                topConsumersCard
                activityCard
            }
        }
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

    private var heroStatusBlock: some View {
        VStack(alignment: .leading, spacing: density == .compact ? 7 : 9) {
            HStack(spacing: 8) {
                Circle()
                    .fill(healthColor.opacity(0.72))
                    .frame(width: 8, height: 8)
                Text(t("СОСТОЯНИЕ СИСТЕМЫ", "SYSTEM HEALTH"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(healthColor)
                Text("· \(healthScoreText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(healthTitle)
                .font(.system(size: density == .compact ? 24 : 26, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(healthSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button {
                    rootModel.openSection(.smartCare)
                } label: {
                    Label(t("Открыть Smart Care", "Open Smart Care"), systemImage: "sparkles")
                }
                .buttonStyle(DRaySecondaryButtonStyle())
                .controlSize(.small)

                Button {
                    rootModel.openSection(focusSection)
                } label: {
                    Label(focusActionTitle, systemImage: focusIcon)
                }
                .buttonStyle(DRaySecondaryButtonStyle())
                .controlSize(.small)
            }
        }
        .frame(maxWidth: density == .compact ? 360 : 440, alignment: .leading)
    }

    private var heroTrendBlock: some View {
        healthFormulaCard
    }

    @ViewBuilder
    private func metricTiles(minWidth: CGFloat? = nil) -> some View {
        DRayDashboardMetricTile(
            title: t("Хранилище", "Storage"),
            value: usedStorageText,
            subtitle: totalStorageText,
            icon: "internaldrive",
            tint: .blue,
            progress: diskUsedRatio,
            action: { rootModel.openSection(.spaceLens) }
        )
        .frame(minWidth: minWidth)
        DRayDashboardMetricTile(
            title: t("Память", "Memory"),
            value: memoryUsedText,
            subtitle: memoryTotalText,
            icon: "memorychip",
            tint: .purple,
            progress: memoryUsedRatio,
            action: { rootModel.openSection(.performance) }
        )
        .frame(minWidth: minWidth)
        DRayDashboardMetricTile(
            title: t("Батарея", "Battery"),
            value: batteryValueText,
            subtitle: batterySubtitle,
            icon: "battery.75percent",
            tint: .green,
            progress: batteryProgress,
            action: { rootModel.openSection(.performance) }
        )
        .frame(minWidth: minWidth)
        DRayDashboardMetricTile(
            title: "CPU",
            value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
            subtitle: t("текущая нагрузка", "current load"),
            icon: "waveform.path.ecg",
            tint: .orange,
            progress: min(1, monitor.snapshot.cpuLoadPercent / 100),
            action: { rootModel.openSection(.performance) }
        )
        .frame(minWidth: minWidth)
    }

    private func overviewActionRow(_ item: OverviewRecommendation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.tint.opacity(0.74))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.032), in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.055), lineWidth: 0.7))

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
            .buttonStyle(DRaySecondaryButtonStyle())
            .controlSize(.small)
        }
        .padding(8)
        .calmGlass(.nestedCard, cornerRadius: 10)
    }

    private func consumerRow(_ consumer: ProcessConsumer, rank: Int) -> some View {
        HStack(spacing: 9) {
            Text("\(rank)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(consumer.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("MEM \(Int(consumer.memoryMB))MB · EI \(String(format: "%.1f", consumer.batteryImpactScore))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(Int(consumer.cpuPercent))%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    private var healthFormulaCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("Индекс", "Index"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(healthScoreText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(healthColor)
                    .monospacedDigit()
            }
            healthFactorRow(title: "CPU", valueText: "\(Int(monitor.snapshot.cpuLoadPercent))%", tint: .orange)
            healthFactorRow(title: t("Память", "Memory"), valueText: "\(Int(monitor.snapshot.memoryPressurePercent))%", tint: .purple)
            healthFactorRow(title: t("Хранилище", "Storage"), valueText: "\(Int(diskUsedRatio * 100))%", tint: .blue)
            healthFactorRow(
                title: t("Доступ", "Access"),
                valueText: rootModel.permissions.hasFullDiskAccess ? t("Вкл", "On") : t("Огр.", "Limited"),
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
        .calmGlass(.nestedCard, cornerRadius: 12)
    }

    private func healthFactorRow(title: String, valueText: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint.opacity(0.60))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Spacer(minLength: 8)
            Text(valueText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
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

    private var healthScoreText: String {
        "\(Int(healthScore * 100))/100"
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

    private var healthColor: Color {
        if healthScore >= 0.76 { return .accentColor }
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
            tint: .teal,
            actionTitle: t("Открыть", "Open"),
            section: .smartCare
        ))
        return Array(items.prefix(3))
    }

    private var topConsumers: [ProcessConsumer] {
        Array(monitor.snapshot.topCPUConsumers.prefix(5))
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
            .init(title: t("Uptime", "Uptime"), value: uptimeText, icon: "clock", tint: .secondary),
            .init(title: t("Target", "Target"), value: rootModel.selectedTarget.name, icon: "scope", tint: .secondary),
            .init(title: "Full Disk", value: rootModel.permissions.hasFullDiskAccess ? "On" : "Required", icon: "lock.shield", tint: rootModel.permissions.hasFullDiskAccess ? .green : .orange),
            .init(title: t("Network", "Network"), value: networkText, icon: "wifi", tint: .secondary)
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
