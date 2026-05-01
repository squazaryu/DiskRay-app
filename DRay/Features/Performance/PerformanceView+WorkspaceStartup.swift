import SwiftUI
import AppKit

extension PerformanceView {
    var startupWorkspace: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Startup Diagnostics", "Startup Diagnostics"))
                        .font(.headline)
                    Text(t("Launch impact, review candidates and cleanup controls.", "Launch impact, review candidates and cleanup controls."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

            HStack(spacing: layoutMetrics.cardSpacing) {
                DRayCompactInfoTile(
                    title: t("Записи", "Entries"),
                    value: "\(startupEntries.count)",
                    subtitle: t("startup items", "startup items"),
                    icon: "power",
                    tint: .blue,
                    progress: min(1, Double(startupEntries.count) / 50)
                )
                DRayCompactInfoTile(
                    title: t("К review", "Review"),
                    value: "\(startupReviewCount)",
                    subtitle: t("need attention", "need attention"),
                    icon: "exclamationmark.triangle",
                    tint: .orange,
                    progress: startupEntries.isEmpty ? 0 : Double(startupReviewCount) / Double(startupEntries.count)
                )
                DRayCompactInfoTile(
                    title: t("Footprint", "Footprint"),
                    value: ByteCountFormatter.string(fromByteCount: startupTotalBytes, countStyle: .file),
                    subtitle: t("total size", "total size"),
                    icon: "externaldrive",
                    tint: .teal,
                    progress: min(1, Double(startupTotalBytes) / Double(200 * 1_048_576))
                )
                DRayCompactInfoTile(
                    title: t("Burden", "Burden"),
                    value: severityLabel(for: startupBurdenValue),
                    subtitle: t("launch impact", "launch impact"),
                    icon: "gauge.with.dots.needle.67percent",
                    tint: severityColor(for: startupBurdenValue),
                    progress: startupBurdenValue / 100
                )
            }

            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    performanceCardTitle(t("Burden Scale", "Burden Scale"), icon: "speedometer", tint: severityColor(for: startupBurdenValue))
                DiagnosticBurdenBar(
                    value: startupBurdenValue,
                        label: t("Launch Burden", "Launch Burden"),
                    detail: t("Комбинирует количество и размер startup-компонентов", "Combines count and footprint of startup components")
                )
                    .frame(height: 56)

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
                .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
                .padding(layoutMetrics.cardSpacing)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)

                VStack(alignment: .leading, spacing: 8) {
                    performanceCardTitle(t("Local Actions", "Local Actions"), icon: "bolt", tint: .green)
                    DRayActionRow(
                        title: t("Disable Selected", "Disable Selected"),
                        subtitle: t("Move selected startup entries to Trash.", "Move selected startup entries to Trash."),
                        icon: "trash",
                        tint: .orange,
                        actionTitle: t("Disable", "Disable")
                    ) { requestStartupCleanup() }
                    .disabled(selectedEntries.isEmpty)

                    DRayActionRow(
                        title: t("Select Heavy", "Select Heavy"),
                        subtitle: t("Select high-impact items for review.", "Select high-impact items for review."),
                        icon: "exclamationmark.triangle",
                        tint: .red,
                        actionTitle: t("Select", "Select")
                    ) {
                        selectedPaths = Set(startupEntries.filter { startupImpactLevel(for: $0) == .high }.map { $0.url.path })
                    }
                    .disabled(startupEntries.isEmpty)
                }
                .frame(width: 330, alignment: .topLeading)
                .frame(minHeight: 164, alignment: .topLeading)
                .padding(layoutMetrics.cardSpacing)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                performanceCardTitle(t("Ranked Startup Items", "Ranked Startup Items"), icon: "list.number", tint: .blue)

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
            .padding(layoutMetrics.cardSpacing)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
        }
    }
}
