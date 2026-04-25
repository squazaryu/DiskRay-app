import SwiftUI

extension PerformanceView {
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

    var latestNetworkResult: NetworkSpeedTestResult? {
        model.performance.networkSpeedTestResult
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

    var networkLatencyBurdenValue: Double {
        guard let result = latestNetworkResult, result.isSuccess else { return 0 }
        let responsiveness = max(result.responsivenessMs ?? 0, 0)
        return min(100, (responsiveness / 180) * 100)
    }

    var networkThroughputBurdenValue: Double {
        guard let result = latestNetworkResult, result.isSuccess else { return 0 }
        let down = max(result.downlinkMbps ?? 0, 0)
        let up = max(result.uplinkMbps ?? 0, 0)
        let combined = down + up
        let qualityScore = min(100, (combined / 240) * 100)
        return max(0, 100 - qualityScore)
    }

    var networkBurdenSummaryText: String {
        if latestNetworkResult == nil {
            return t("Запусти тест для оценки латентности и канала.", "Run a test to evaluate latency and throughput.")
        }
        if latestNetworkResult?.isSuccess == false {
            return t("Последний тест завершился ошибкой, повтори измерение.", "Last test failed, run another measurement.")
        }
        return t(
            "Ниже показано, что сейчас ограничивает качество сильнее: отклик или пропускная способность.",
            "The bars below show what currently limits quality more: responsiveness or throughput."
        )
    }

    var recentNetworkRows: [NetworkHistoryPoint] {
        Array(networkHistory.suffix(8).reversed())
    }

    var bestDownlinkInSession: Double {
        max(networkHistory.map(\.downMbps).max() ?? 0, 0.01)
    }

    var bestResponsivenessInSession: Double {
        max(networkHistory.map(\.responsivenessMs).filter { $0 > 0 }.min() ?? 0, 0.01)
    }

    func downlinkShare(from point: NetworkHistoryPoint) -> Double {
        min(100, max(0, (point.downMbps / bestDownlinkInSession) * 100))
    }

    func responsivenessQualityShare(from point: NetworkHistoryPoint) -> Double {
        min(100, max(0, (bestResponsivenessInSession / max(point.responsivenessMs, 0.01)) * 100))
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
}
