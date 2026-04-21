import SwiftUI
import AppKit

extension PerformanceView {
    var startupWorkspace: some View {
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
}
