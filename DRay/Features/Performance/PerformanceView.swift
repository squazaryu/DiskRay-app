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
    @State private var showStartupEntries = false
    @State private var showLiveSummary = false

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: PerformanceViewModel(root: rootModel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            loadPanel
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.06, padding: 12)

            if model.performance.report == nil && !model.performance.isScanRunning {
                ContentUnavailableView(
                    t("Диагностика ещё не запускалась", "No Diagnostics Yet"),
                    systemImage: "speedometer",
                    description: Text(t(
                        "Запусти диагностику, чтобы проверить автозапуск и рекомендации по обслуживанию.",
                        "Run diagnostics to inspect startup pressure and maintenance opportunities."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.03, padding: 0)
            } else if let cleanup = model.performance.startupCleanupReport {
                Text(t(
                    "Последняя очистка автозапуска: перемещено \(cleanup.moved), ошибок \(cleanup.failed), пропущено \(cleanup.skippedProtected)",
                    "Last startup cleanup: moved \(cleanup.moved), failed \(cleanup.failed), skipped \(cleanup.skippedProtected)"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
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
        }
        .onDisappear {
            monitor.stop()
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: t("Производительность", "Performance"),
            subtitle: t(
                "Диагностика автозапуска и рекомендации по обслуживанию.",
                "Startup diagnostics and maintenance recommendations."
            )
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(t("Запустить диагностику", "Run Diagnostics")) { model.runPerformanceScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.performance.isScanRunning)

                    Button(t("Отключить выбранные", "Disable Selected")) {
                        showCleanupConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedEntries.isEmpty)

                    Button(t("Экспорт лога", "Export Ops Log")) {
                        if let url = model.exportOperationLogReport() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    .buttonStyle(.bordered)

                    Button(t("Показать crash log", "Reveal Crash Log")) {
                        model.revealCrashTelemetry()
                    }
                    .buttonStyle(.bordered)

                    if model.performance.isScanRunning {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(t("Идёт анализ...", "Analyzing..."))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                    }
                }
            }
        }
    }

    private var loadPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Текущая нагрузка", "Live Load"))
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
                loadCard(
                    title: "CPU",
                    value: "\(Int(monitor.snapshot.cpuLoadPercent))%",
                    subtitle: t(
                        "Пользователь \(Int(monitor.snapshot.cpuUserPercent))% · Система \(Int(monitor.snapshot.cpuSystemPercent))%",
                        "User \(Int(monitor.snapshot.cpuUserPercent))% · System \(Int(monitor.snapshot.cpuSystemPercent))%"
                    )
                )
                loadCard(
                    title: t("Память", "Memory"),
                    value: "\(Int(monitor.snapshot.memoryPressurePercent))%",
                    subtitle: "\(ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryUsedBytes, countStyle: .memory)) of \(ByteCountFormatter.string(fromByteCount: monitor.snapshot.memoryTotalBytes, countStyle: .memory))"
                )
                loadCard(
                    title: t("Сеть", "Network"),
                    value: "↓ \(networkSpeedText(monitor.snapshot.networkDownBytesPerSecond))",
                    subtitle: "↑ \(networkSpeedText(monitor.snapshot.networkUpBytesPerSecond))"
                )
                loadCard(
                    title: t("Батарея", "Battery"),
                    value: batteryPrimaryText,
                    subtitle: batterySecondaryText
                )
            }

            if let report = model.performance.report {
                diagnosticsSummary(report)
            }

            if let delta = model.performanceQuickActionDelta {
                quickActionDeltaPanel(delta)
            }

            if !monitor.snapshot.topCPUConsumers.isEmpty || !monitor.snapshot.topMemoryConsumers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Топ потребителей", "Top Consumers"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(consumerRows.prefix(4))) { consumer in
                        HStack {
                            Text(consumer.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text("CPU \(Int(consumer.cpuPercent))%")
                                .foregroundStyle(.secondary)
                            Text(t("ПАМ \(Int(consumer.memoryMB)) MB", "MEM \(Int(consumer.memoryMB)) MB"))
                                .foregroundStyle(.secondary)
                            Text(t("БАТ \(String(format: "%.1f", consumer.batteryImpactScore))", "BAT \(String(format: "%.1f", consumer.batteryImpactScore))"))
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func quickActionDeltaPanel(_ delta: QuickActionDeltaReport) -> some View {
        HStack(spacing: 8) {
            GlassPillBadge(
                title: t("Действие: \(delta.actionTitle)", "Action: \(delta.actionTitle)"),
                tint: .blue
            )
            GlassPillBadge(
                title: t(
                    "Элементы \(delta.beforeItems) → \(delta.afterItems)",
                    "Items \(delta.beforeItems) -> \(delta.afterItems)"
                ),
                tint: .green
            )
            GlassPillBadge(
                title: t(
                    "Размер \(ByteCountFormatter.string(fromByteCount: delta.beforeBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: delta.afterBytes, countStyle: .file))",
                    "Size \(ByteCountFormatter.string(fromByteCount: delta.beforeBytes, countStyle: .file)) -> \(ByteCountFormatter.string(fromByteCount: delta.afterBytes, countStyle: .file))"
                ),
                tint: .orange
            )
            Spacer()
            Text(t(
                "Обновлено \(relativeTime(delta.createdAt))",
                "Updated \(relativeTime(delta.createdAt))"
            ))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var consumerRows: [LiveConsumerRow] {
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

    private func loadCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func diagnosticsSummary(_ report: PerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showLiveSummary.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showLiveSummary ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(t("Сводка диагностики", "Diagnostics Summary"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                }
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    summaryBadge(
                        title: t("Автозапуск", "Startup"),
                        value: "\(report.startupEntries.count)"
                    )
                    summaryBadge(
                        title: t("Размер", "Size"),
                        value: ByteCountFormatter.string(fromByteCount: report.startupTotalBytes, countStyle: .file)
                    )
                    summaryBadge(
                        title: t("Свободно", "Free"),
                        value: report.diskFreeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "n/a"
                    )
                    summaryBadge(
                        title: t("Изменено", "Tweaks"),
                        value: "\(model.performance.activeLoadReliefAdjustments)"
                    )
                }
            }

            if showLiveSummary {
                if !report.recommendations.isEmpty {
                    Divider()
                    Text(t("Рекомендации автозапуска", "Startup Recommendations"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(report.recommendations) { rec in
                        recommendationRow(rec)
                    }
                }

                Divider()
                HStack {
                    Text(t("Элементы автозапуска", "Startup Entries"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(showStartupEntries ? t("Скрыть", "Hide") : t("Показать", "Show")) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showStartupEntries.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if showStartupEntries {
                    VStack(spacing: 6) {
                        ForEach(report.startupEntries.prefix(12)) { entry in
                            startupEntryRow(entry)
                        }
                        if report.startupEntries.count > 12 {
                            Text(t(
                                "Показаны первые \(min(12, report.startupEntries.count)) из \(report.startupEntries.count)",
                                "Showing first \(min(12, report.startupEntries.count)) of \(report.startupEntries.count)"
                            ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func recommendationRow(_ rec: PerformanceRecommendation) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.title)
                    .font(.subheadline.weight(.semibold))
                Text(rec.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let actionTitle = rec.actionTitle {
                Button(actionTitle) {
                    handleRecommendationAction(rec.action)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func startupEntryRow(_ entry: StartupEntry) -> some View {
        HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { selectedPaths.contains(entry.url.path) },
                    set: { isOn in
                        if isOn { selectedPaths.insert(entry.url.path) }
                        else { selectedPaths.remove(entry.url.path) }
                    }
                )
            )
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
            Text(ByteCountFormatter.string(fromByteCount: entry.sizeInBytes, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(t("Показать", "Reveal")) {
                NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var selectedEntries: [StartupEntry] {
        guard let report = model.performance.report else { return [] }
        return report.startupEntries.filter { selectedPaths.contains($0.url.path) }
    }

    private func networkSpeedText(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    private var batteryPrimaryText: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return "n/a" }
        return "\(percent)%"
    }

    private var batterySecondaryText: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else { return t("Нет данных батареи", "No battery data") }
        let charging = monitor.snapshot.batteryIsCharging ?? false
        let minutes = monitor.snapshot.batteryMinutesRemaining
        if let minutes {
            let hours = minutes / 60
            let mins = minutes % 60
            if charging {
                return t(
                    "\(percent)% · зарядка (\(hours)ч \(mins)м)",
                    "\(percent)% · charging (\(hours)h \(mins)m)"
                )
            }
            return t(
                "\(percent)% · осталось \(hours)ч \(mins)м",
                "\(percent)% · \(hours)h \(mins)m left"
            )
        }
        return charging ? t("\(percent)% · зарядка", "\(percent)% · charging") : "\(percent)%"
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
            guard let report = model.performance.report else { return }
            selectedPaths = Set(report.startupEntries.map { $0.url.path })
        case .selectHeavyStartup:
            guard let report = model.performance.report else { return }
            let heavy = report.startupEntries
                .filter { $0.sizeInBytes >= 100 * 1_048_576 }
                .map { $0.url.path }
            selectedPaths = Set(heavy)
        case .openSmartCare:
            model.openSection(.smartCare)
            model.runSmartScan()
        case .runDiagnostics:
            model.runPerformanceScan()
        case .none:
            break
        }
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

private struct LiveConsumerRow: Identifiable {
    let id: String
    let displayName: String
    var cpuPercent: Double
    var memoryMB: Double
    var batteryImpactScore: Double
}
