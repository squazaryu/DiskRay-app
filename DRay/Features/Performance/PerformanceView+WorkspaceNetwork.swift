import SwiftUI

extension PerformanceView {
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
