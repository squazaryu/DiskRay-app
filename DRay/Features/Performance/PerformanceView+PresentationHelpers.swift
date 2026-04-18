import SwiftUI

extension PerformanceView {
    func appendTrend(value: Double, to trend: inout [Double]) {
        trend.append(value)
        if trend.count > 24 {
            trend.removeFirst(trend.count - 24)
        }
    }

    func appendNetworkHistory(_ result: NetworkSpeedTestResult) {
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

    func requestStartupCleanup() {
        guard !selectedEntries.isEmpty else { return }
        if model.confirmBeforeStartupCleanup {
            showCleanupConfirm = true
            return
        }
        model.cleanupStartupEntries(selectedEntries)
        selectedPaths.removeAll()
    }

    var rankedLiveConsumers: [LiveConsumerRow] {
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

    func rankedContribution(for consumer: LiveConsumerRow, in ranked: [LiveConsumerRow]) -> Double {
        let cpuTotal = max(ranked.reduce(0.0) { $0 + $1.cpuPercent }, 0.1)
        let memTotal = max(ranked.reduce(0.0) { $0 + $1.memoryMB }, 0.1)
        let cpuShare = (consumer.cpuPercent / cpuTotal) * 100
        let memShare = (consumer.memoryMB / memTotal) * 100
        return min(100, max(0, (cpuShare * 0.65) + (memShare * 0.35)))
    }

    func normalizedConsumerKey(_ name: String) -> String {
        shortConsumerName(name).lowercased()
    }

    func shortConsumerName(_ name: String) -> String {
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

    var startupEntries: [StartupEntry] {
        model.performance.report?.startupEntries ?? []
    }

    var selectedEntries: [StartupEntry] {
        startupEntries.filter { selectedPaths.contains($0.url.path) }
    }

    var startupTotalBytes: Int64 {
        startupEntries.reduce(0) { $0 + $1.sizeInBytes }
    }

    var maxStartupEntrySize: Int64 {
        startupEntries.map(\.sizeInBytes).max() ?? 1
    }

    var startupReviewCount: Int {
        startupEntries.filter { startupImpactLevel(for: $0) != .low }.count
    }

    var startupBurdenValue: Double {
        let countScore = min(100.0, Double(startupEntries.count) * 2.4)
        let sizeScore = min(100.0, Double(startupTotalBytes) / Double(80 * 1_048_576))
        return min(100, (countScore * 0.55) + (sizeScore * 0.45))
    }

    var startupImpactDistribution: (low: Double, review: Double, high: Double) {
        guard !startupEntries.isEmpty else { return (0, 0, 0) }
        let low = Double(startupEntries.filter { startupImpactLevel(for: $0) == .low }.count)
        let review = Double(startupEntries.filter { startupImpactLevel(for: $0) == .review }.count)
        let high = Double(startupEntries.filter { startupImpactLevel(for: $0) == .high }.count)
        let total = max(low + review + high, 1)
        return ((low / total) * 100, (review / total) * 100, (high / total) * 100)
    }

    func startupImpactLevel(for entry: StartupEntry) -> StartupImpact {
        if entry.sizeInBytes >= 100 * 1_048_576 {
            return .high
        }
        if entry.sizeInBytes >= 25 * 1_048_576 {
            return .review
        }
        return .low
    }

    var networkStatusChip: (title: String, tint: Color)? {
        guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return nil }
        return (
            title: "\(t("Сеть", "Network")): \(networkQualityTag(from: result))",
            tint: networkQualityColor(from: result)
        )
    }

    var networkQualityValue: Double? {
        guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return nil }
        let resp = max(1, result.responsivenessMs ?? 140)
        let down = result.downlinkMbps ?? 0
        let up = result.uplinkMbps ?? 0
        let respPenalty = min(100.0, (resp / 220.0) * 100.0)
        let throughputBonus = min(30.0, (down + up) / 12.0)
        return max(0, min(100, respPenalty + 20 - throughputBonus))
    }

    var networkQualityLabel: String {
        guard let result = model.performance.networkSpeedTestResult, result.isSuccess else {
            return t("Сетевых данных пока нет", "No network data yet")
        }
        return networkQualityText(from: result)
    }

    var networkInterpretation: String {
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

    func networkQualityTag(from result: NetworkSpeedTestResult) -> String {
        let resp = result.responsivenessMs ?? 999
        let down = result.downlinkMbps ?? 0
        if resp <= 45 && down >= 120 { return t("Отлично", "Excellent") }
        if resp <= 90 && down >= 40 { return t("Хорошо", "Good") }
        if resp <= 150 { return t("Умеренно", "Fair") }
        return t("Слабый отклик", "Poor latency")
    }

    func networkQualityColor(from result: NetworkSpeedTestResult) -> Color {
        let tag = networkQualityTag(from: result)
        switch tag {
        case t("Отлично", "Excellent"): return .green
        case t("Хорошо", "Good"): return .blue
        case t("Умеренно", "Fair"): return .orange
        default: return .red
        }
    }

    func networkQualityText(from result: NetworkSpeedTestResult) -> String {
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

    var batteryHealthLabel: String {
        guard let health = model.performance.batteryEnergyReport?.battery.healthPercent else {
            return t("Нет данных", "No data")
        }
        if health >= 88 { return t("Хорошо", "Good") }
        if health >= 75 { return t("Умеренно", "Fair") }
        return t("Внимание", "Attention")
    }

    var batteryHealthColor: Color {
        guard let health = model.performance.batteryEnergyReport?.battery.healthPercent else {
            return .secondary
        }
        if health >= 88 { return .green }
        if health >= 75 { return .orange }
        return .red
    }

    func severityLabel(for value: Double) -> String {
        switch value {
        case 0..<45: return t("Низко", "Low")
        case 45..<75: return t("Умеренно", "Moderate")
        default: return t("Высоко", "High")
        }
    }

    func severityColor(for value: Double) -> Color {
        switch value {
        case 0..<45: return .green
        case 45..<75: return .orange
        default: return .red
        }
    }

    var topCPUConsumerName: String {
        guard let top = monitor.snapshot.topCPUConsumers.first else { return "n/a" }
        return shortConsumerName(top.name)
    }

    var topCPUConsumerValue: String {
        guard let top = monitor.snapshot.topCPUConsumers.first else { return t("Нет данных", "No data") }
        return "CPU \(Int(top.cpuPercent))% · \(Int(top.memoryMB)) MB"
    }

    var topMemoryConsumerName: String {
        guard let top = monitor.snapshot.topMemoryConsumers.first else { return "n/a" }
        return shortConsumerName(top.name)
    }

    var topMemoryConsumerValue: String {
        guard let top = monitor.snapshot.topMemoryConsumers.first else { return t("Нет данных", "No data") }
        return "MEM \(Int(top.memoryMB)) MB · CPU \(Int(top.cpuPercent))%"
    }

    var cpuReliefCandidates: [ProcessConsumer] {
        let heavy = monitor.snapshot.topCPUConsumers.filter { $0.cpuPercent >= 18 }
        return heavy.isEmpty ? Array(monitor.snapshot.topCPUConsumers.prefix(3)) : heavy
    }

    var memoryReliefCandidates: [ProcessConsumer] {
        let heavy = monitor.snapshot.topMemoryConsumers.filter { $0.memoryMB >= 700 }
        return heavy.isEmpty ? Array(monitor.snapshot.topMemoryConsumers.prefix(3)) : heavy
    }

    var reliefDialogTitle: String {
        switch pendingReliefAction {
        case .cpu:
            return t("Снизить нагрузку CPU (понизить приоритет тяжёлых приложений)?", "Reduce CPU load by deprioritizing heavy apps?")
        case .memory:
            return t("Снизить нагрузку памяти (понизить приоритет тяжёлых приложений)?", "Reduce memory pressure by deprioritizing heavy apps?")
        case .none:
            return t("Изменить live-нагрузку?", "Adjust live load?")
        }
    }

    var reliefActionTitle: String {
        switch pendingReliefAction {
        case .cpu: return t("Понизить приоритет CPU-лидеров", "Lower Priority for Top CPU Apps")
        case .memory: return t("Понизить приоритет memory-лидеров", "Lower Priority for Top Memory Apps")
        case .none: return t("Выполнить", "Run")
        }
    }

    func executeReliefAction() {
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

    func handleRecommendationAction(_ action: PerformanceRecommendationAction) {
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

    func optionalPercent(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)%"
    }

    func optionalWatts(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f W", value)
    }

    func optionalTemperature(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f °C", value)
    }

    func optionalVolts(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f", value)
    }

    func optionalAmps(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f", value)
    }

    func optionalMbps(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f Mbps", value)
    }

    func optionalMilliseconds(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f ms", value)
    }

    func batteryStateText(_ snapshot: BatteryEnergySnapshot) -> String {
        guard let isCharging = snapshot.isCharging else {
            return t("Статус n/a", "Status n/a")
        }
        return isCharging ? t("Заряжается", "Charging") : t("Разряжается", "Discharging")
    }

    func timeEstimateText(_ snapshot: BatteryEnergySnapshot) -> String {
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

    func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
