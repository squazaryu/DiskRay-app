import SwiftUI

extension PerformanceView {
    var networkWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Network Diagnostics", "Network Diagnostics"))
                        .font(.headline)
                    Text(t(
                        "On-demand diagnostics for throughput and responsiveness.",
                        "On-demand diagnostics for throughput and responsiveness."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Запустить тест", "Run Test")) {
                    model.runNetworkSpeedTest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.performance.isNetworkSpeedTestRunning)

                Button(t("Запустить диагностику", "Run Diagnostics")) {
                    model.runPerformanceScan()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(t("Latest Result", "Latest Result"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let chip = networkStatusChip {
                            StatusChip(title: chip.title, tint: chip.tint)
                        }
                    }

                    HStack(spacing: 8) {
                        metricCard(
                            title: t("Скачивание", "Download"),
                            value: optionalMbps(latestNetworkResult?.downlinkMbps),
                            subtitle: t("Пропускная способность вниз", "Downlink throughput")
                        )
                        metricCard(
                            title: t("Отдача", "Upload"),
                            value: optionalMbps(latestNetworkResult?.uplinkMbps),
                            subtitle: t("Пропускная способность вверх", "Uplink throughput")
                        )
                        metricCard(
                            title: t("Отклик", "Responsiveness"),
                            value: optionalMilliseconds(latestNetworkResult?.responsivenessMs),
                            subtitle: t("Влияет на интерактивность", "Impacts interactive tasks")
                        )
                        metricCard(
                            title: "Base RTT",
                            value: optionalMilliseconds(latestNetworkResult?.baseRTTMs),
                            subtitle: t("Базовая задержка сети", "Baseline network latency")
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("Quality Interpretation", "Quality Interpretation"))
                            .font(.subheadline.weight(.semibold))
                        Text(networkInterpretation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let last = latestNetworkResult {
                            Text(t(
                                "Last measured: \(relativeTime(last.measuredAt))",
                                "Last measured: \(relativeTime(last.measuredAt))"
                            ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !networkHistory.isEmpty {
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
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Burden Analysis", "Burden Analysis"))
                        .font(.subheadline.weight(.semibold))
                    Text(networkBurdenSummaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    DiagnosticBurdenBar(
                        value: networkLatencyBurdenValue,
                        label: t("Latency Burden", "Latency Burden"),
                        detail: t("Higher means slower interaction.", "Higher means slower interaction.")
                    )
                    .frame(height: 48)

                    DiagnosticBurdenBar(
                        value: networkThroughputBurdenValue,
                        label: t("Throughput Burden", "Throughput Burden"),
                        detail: t("Higher means transfer speed is limiting.", "Higher means transfer speed is limiting.")
                    )
                    .frame(height: 48)

                    if let result = latestNetworkResult, result.isSuccess {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("Focus", "Focus"))
                                .font(.caption.weight(.semibold))
                            Text(networkQualityText(from: result))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .frame(minWidth: 250, maxWidth: 290, alignment: .topLeading)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !recentNetworkRows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Recent Session History", "Recent Session History"))
                        .font(.subheadline.weight(.semibold))

                    ForEach(recentNetworkRows) { point in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(relativeTime(point.measuredAt))
                                    .font(.caption.weight(.semibold))
                                Text(point.measuredAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 74, alignment: .leading)

                            RankedShareBar(
                                title: t("Download", "Download"),
                                subtitle: optionalMbps(point.downMbps),
                                percentage: downlinkShare(from: point),
                                accent: .blue
                            )
                            RankedShareBar(
                                title: t("Responsiveness", "Responsiveness"),
                                subtitle: optionalMilliseconds(point.responsivenessMs),
                                percentage: responsivenessQualityShare(from: point),
                                accent: .orange
                            )

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(optionalMbps(point.upMbps))
                                    .font(.caption.weight(.semibold))
                                Text(t("Upload", "Upload"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 84, alignment: .trailing)
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let error = latestNetworkResult?.errorMessage {
                Text(t("Тест не выполнен: \(error)", "Speed test failed: \(error)"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
