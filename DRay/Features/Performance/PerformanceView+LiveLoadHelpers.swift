import SwiftUI

extension PerformanceView {
    func appendTrend(value: Double, to trend: inout [Double]) {
        trend.append(value)
        if trend.count > 24 {
            trend.removeFirst(trend.count - 24)
        }
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
}
