import SwiftUI

struct RecoveryView: View {
    @ObservedObject var model: RootViewModel
    @State private var selected = Set<RecentlyDeletedItem.ID>()
    @State private var showRestoreFailed = false
    @State private var resultMessage: String?
    @State private var rollbackMessage: String?
    @State private var workspaceTab: RecoveryWorkspaceTab = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            workspaceNavigation

            Group {
                switch workspaceTab {
                case .overview:
                    overviewWorkspace
                case .recentlyDeleted:
                    recentlyDeletedWorkspace
                case .rollback:
                    rollbackWorkspace
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: workspaceTab == .overview ? 12 : 10)
        }
        .padding()
        .alert(t("Ошибка восстановления", "Restore failed"), isPresented: $showRestoreFailed) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(t(
                "Не удалось восстановить один или несколько элементов. Проверь, что файлы ещё в Корзине и доступны для записи.",
                "Could not restore one or more selected items. Ensure files are still in Trash and writable."
            ))
        }
        .alert(t("Результат", "Result"), isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .alert(t("Rollback", "Rollback"), isPresented: Binding(
            get: { rollbackMessage != nil },
            set: { if !$0 { rollbackMessage = nil } }
        )) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(rollbackMessage ?? "")
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: t("Восстановление", "Recovery"),
            subtitle: t(
                "История удалённых файлов и откат системных действий с понятным контролем.",
                "Deleted-item history and rollback actions with clear operational control."
            )
        ) {
            recoveryHeaderActions
        }
    }

    @ViewBuilder
    private var recoveryHeaderActions: some View {
        HStack(spacing: 8) {
            switch workspaceTab {
            case .overview:
                Button(t("Удалённые", "Recently Deleted")) {
                    workspaceTab = .recentlyDeleted
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(t("Rollback", "Rollback")) {
                    workspaceTab = .rollback
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .recentlyDeleted:
                Button(t("Восстановить выбранные", "Restore Selected")) {
                    restoreSelectedItems()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selected.isEmpty)

                Button(t("Выбрать всё", "Select All")) {
                    selected = Set(model.recentlyDeleted.map(\.id))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.recentlyDeleted.isEmpty)

            case .rollback:
                Button(t("Очистить применённые", "Clear Applied")) {
                    clearAppliedRollbackSessions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.quickActionRollbackSessions.allSatisfy(\.canRollback))
            }
        }
    }

    @ViewBuilder
    private var commandStrip: some View {
        HStack(spacing: 8) {
            switch workspaceTab {
            case .overview:
                Button(t("Открыть удалённые", "Open Recently Deleted")) {
                    workspaceTab = .recentlyDeleted
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(t("Открыть Rollback", "Open Rollback")) {
                    workspaceTab = .rollback
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .recentlyDeleted:
                Button(t("Восстановить выбранные", "Restore Selected")) {
                    restoreSelectedItems()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selected.isEmpty)

                Button(t("Выбрать всё", "Select All")) {
                    selected = Set(model.recentlyDeleted.map(\.id))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.recentlyDeleted.isEmpty)

                Button(t("Снять выбор", "Clear Selection")) {
                    selected.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selected.isEmpty)

            case .rollback:
                Button(t("Очистить применённые", "Clear Applied")) {
                    clearAppliedRollbackSessions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.quickActionRollbackSessions.allSatisfy(\.canRollback))

                Button(t("Показать активные", "Show Active")) {
                    workspaceTab = .overview
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text(t("Обзор", "Overview")).tag(RecoveryWorkspaceTab.overview)
                Text(t("Удалённые", "Recently Deleted")).tag(RecoveryWorkspaceTab.recentlyDeleted)
                Text(t("Rollback", "Rollback")).tag(RecoveryWorkspaceTab.rollback)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
            Spacer(minLength: 8)
        }
        .padding(6)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.03, padding: 0)
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            statusTile(
                title: t("Удалённые", "Recently Deleted"),
                value: "\(model.recentlyDeleted.count)",
                tint: .blue
            )
            statusTile(
                title: t("Выбрано", "Selected"),
                value: "\(selected.count)",
                tint: selected.isEmpty ? .secondary : .green
            )
            statusTile(
                title: t("Rollback сессии", "Rollback Sessions"),
                value: "\(model.quickActionRollbackSessions.count)",
                tint: .orange
            )
            statusTile(
                title: t("Готово к откату", "Rollback Ready"),
                value: "\(model.quickActionRollbackSessions.filter(\.canRollback).count)",
                tint: .purple
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var overviewWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            recoveryHeroCard

            recoveryOverviewGrid

            if model.recentlyDeleted.isEmpty && model.quickActionRollbackSessions.isEmpty {
                ContentUnavailableView(
                    t("История пуста", "History is empty"),
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text(t(
                        "После операций DRay здесь появятся удалённые элементы и rollback-сессии.",
                        "Deleted items and rollback sessions will appear here after DRay operations."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Рекомендация", "Focus"))
                        .font(.subheadline.weight(.semibold))
                    Text(t(
                        "Проверь вкладку «Удалённые» для восстановления файлов и «Rollback» для отмены системных действий.",
                        "Use Recently Deleted for file restore and Rollback for reverting system actions."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var recoveryOverviewGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("Состояние защиты", "Protection State"))
                    .font(.headline)
                DRayDonutChartView(
                    segments: recoverySegments,
                    centerTitle: recoveryStatusTitle,
                    centerSubtitle: t("статус", "status"),
                    lineWidth: 18
                )
                .frame(maxWidth: .infinity)
                .frame(height: 148)
                HStack(spacing: 8) {
                    recoveryTinyMetric(title: t("Удалённые", "Deleted"), value: "\(model.recentlyDeleted.count)", tint: .blue)
                    recoveryTinyMetric(title: "Rollback", value: "\(model.quickActionRollbackSessions.count)", tint: .purple)
                    recoveryTinyMetric(title: t("Готово", "Ready"), value: "\(rollbackReadyCount)", tint: .green)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
            .padding(12)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("Активность", "Activity"))
                        .font(.headline)
                    Spacer()
                    Button(t("Все", "View All")) { workspaceTab = .recentlyDeleted }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                }

                if recoveryActivityRows.isEmpty {
                    Text(t("Пока нет событий восстановления.", "No recovery activity yet."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 168, alignment: .center)
                } else {
                    VStack(spacing: 10) {
                        ForEach(recoveryActivityRows) { row in
                            DRayActivityTimelineRow(
                                title: row.title,
                                subtitle: row.subtitle,
                                time: row.time,
                                icon: row.icon,
                                tint: row.tint
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
            .padding(12)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text(t("Действия", "Action Center"))
                    .font(.headline)
                recoveryActionRow(
                    title: t("Проверить удалённые", "Review Deleted Items"),
                    subtitle: t("Восстановить файлы из истории DRay", "Restore files tracked by DRay"),
                    icon: "trash",
                    tint: .blue
                ) {
                    workspaceTab = .recentlyDeleted
                }
                recoveryActionRow(
                    title: t("Открыть Rollback", "Open Rollback"),
                    subtitle: t("Отменить действия снижения нагрузки", "Undo load-relief actions"),
                    icon: "arrow.uturn.backward.circle",
                    tint: .purple
                ) {
                    workspaceTab = .rollback
                }
                recoveryActionRow(
                    title: t("Очистить применённые", "Clear Applied"),
                    subtitle: t("Оставить только актуальные сессии", "Keep only actionable sessions"),
                    icon: "checkmark.shield",
                    tint: .green
                ) {
                    clearAppliedRollbackSessions()
                }
                .disabled(model.quickActionRollbackSessions.allSatisfy(\.canRollback))
            }
            .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
            .padding(12)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)
        }
    }

    private var recoveryHeroCard: some View {
        HStack(spacing: 22) {
            DRayLiquidStatusRing(icon: "checkmark.shield", tint: .blue, size: 108)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("СТАТУС ВОССТАНОВЛЕНИЯ", "RECOVERY STATUS"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                Text(recoveryStatusTitle)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                Text(recoveryStatusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    GlassPillBadge(title: t("История: \(model.recentlyDeleted.count)", "History: \(model.recentlyDeleted.count)"), tint: .blue)
                    GlassPillBadge(title: t("Rollback: \(model.quickActionRollbackSessions.count)", "Rollback: \(model.quickActionRollbackSessions.count)"), tint: .purple)
                    GlassPillBadge(
                        title: t(
                            "Готово: \(model.quickActionRollbackSessions.filter(\.canRollback).count)",
                            "Ready: \(model.quickActionRollbackSessions.filter(\.canRollback).count)"
                        ),
                        tint: .green
                    )
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .leading, spacing: 8) {
                protectionRow(title: t("Protected flow", "Protected flow"), value: t("Enabled", "Enabled"), tint: .green)
                protectionRow(title: t("Selected", "Selected"), value: "\(selected.count)", tint: selected.isEmpty ? .secondary : .orange)
                protectionRow(title: t("Last action", "Last action"), value: latestRecoveryActivity, tint: .blue)
            }
            .frame(width: 220)
        }
        .padding(14)
        .glassSurface(cornerRadius: 22, strokeOpacity: 0.11, shadowOpacity: 0.08, padding: 0)
    }

    private func protectionRow(title: String, value: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var recentlyDeletedWorkspace: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if model.recentlyDeleted.isEmpty {
                    ContentUnavailableView(
                        t("История пуста", "No Recently Deleted Items"),
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text(t(
                            "После удаления через DRay элементы появятся здесь с возможностью восстановления.",
                            "Items deleted through DRay will appear here with restore options."
                        ))
                    )
                } else {
                    ForEach(model.recentlyDeleted) { item in
                        recoveryRow(item)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var rollbackWorkspace: some View {
        Group {
            if model.quickActionRollbackSessions.isEmpty {
                ContentUnavailableView(
                    t("Rollback-сессий нет", "No Rollback Sessions"),
                    systemImage: "arrow.uturn.backward.circle",
                    description: Text(t(
                        "После действий снижения нагрузки здесь появятся сессии отката.",
                        "Rollback sessions appear here after load-relief actions."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    quickRollbackSection
                }
            }
        }
    }

    private var recoveryStatusTitle: String {
        if model.recentlyDeleted.isEmpty && model.quickActionRollbackSessions.isEmpty {
            return t("Всё чисто", "All Clear")
        }
        if !model.quickActionRollbackSessions.filter(\.canRollback).isEmpty {
            return t("Откат доступен", "Rollback Available")
        }
        return t("История активна", "History Active")
    }

    private var recoveryStatusSubtitle: String {
        if model.recentlyDeleted.isEmpty && model.quickActionRollbackSessions.isEmpty {
            return t(
                "После операций DRay здесь появятся восстановление и rollback.",
                "Restore and rollback records will appear here after DRay operations."
            )
        }
        if !model.quickActionRollbackSessions.filter(\.canRollback).isEmpty {
            return t(
                "Есть действия, которые можно безопасно откатить.",
                "Some actions can be safely rolled back."
            )
        }
        return t(
            "История удаления сохранена для контроля и восстановления.",
            "Deleted-item history is retained for control and recovery."
        )
    }

    private var latestRecoveryActivity: String {
        if let latestDeleted = model.recentlyDeleted.first {
            return latestDeleted.deletedAt.formatted(date: .abbreviated, time: .omitted)
        }
        if let latestRollback = model.quickActionRollbackSessions.first {
            return latestRollback.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        return t("Нет", "None")
    }

    private var rollbackReadyCount: Int {
        model.quickActionRollbackSessions.filter(\.canRollback).count
    }

    private var recoverySegments: [DRayDonutSegment] {
        if model.recentlyDeleted.isEmpty && model.quickActionRollbackSessions.isEmpty {
            return [
                DRayDonutSegment(title: t("Защищено", "Protected"), value: 1, color: .green)
            ]
        }
        return [
            DRayDonutSegment(title: t("Удалённые", "Deleted"), value: Double(model.recentlyDeleted.count), color: .blue),
            DRayDonutSegment(title: "Rollback", value: Double(model.quickActionRollbackSessions.count), color: .purple),
            DRayDonutSegment(title: t("Готово", "Ready"), value: Double(rollbackReadyCount), color: .green)
        ]
    }

    private struct RecoveryActivityRow: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let time: String
        let icon: String
        let tint: Color
    }

    private var recoveryActivityRows: [RecoveryActivityRow] {
        let deletedRows = model.recentlyDeleted.prefix(2).map { item in
            RecoveryActivityRow(
                title: item.name,
                subtitle: t("Удалено из \(item.originalPath)", "Deleted from \(item.originalPath)"),
                time: item.deletedAt.formatted(date: .omitted, time: .shortened),
                icon: "trash",
                tint: .blue
            )
        }
        let rollbackRows = model.quickActionRollbackSessions.prefix(2).map { session in
            RecoveryActivityRow(
                title: session.actionTitle,
                subtitle: session.canRollback ? t("Откат доступен", "Rollback available") : t("Откат применён", "Rollback applied"),
                time: session.createdAt.formatted(date: .omitted, time: .shortened),
                icon: "arrow.uturn.backward.circle",
                tint: session.canRollback ? .purple : .green
            )
        }
        return Array((deletedRows + rollbackRows).prefix(4))
    }

    private func recoveryTinyMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func recoveryActionRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                DRayIconBadge(icon: icon, tint: tint, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func restoreSelectedItems() {
        let items = model.recentlyDeleted.filter { selected.contains($0.id) }
        var restored = 0
        var failed = 0
        for item in items {
            if model.restoreDeletedItem(item) {
                restored += 1
            } else {
                failed += 1
            }
        }
        selected.removeAll()
        if failed > 0 {
            showRestoreFailed = true
        }
        resultMessage = t(
            "Восстановлено: \(restored), ошибок: \(failed)",
            "Restored: \(restored), failed: \(failed)"
        )
    }

    private var isRussian: Bool {
        model.appLanguage.localeCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    private func recoveryRow(_ item: RecentlyDeletedItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                toggleSelection(item.id)
            } label: {
                Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(item.id) ? Color.accentColor : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.originalPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(t("Удалён", "Deleted")): \(item.deletedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Button(t("Восстановить", "Restore")) {
                    if !model.restoreDeletedItem(item) {
                        showRestoreFailed = true
                    } else {
                        resultMessage = t("Элемент восстановлен.", "Item restored.")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(t("Показать", "Reveal")) {
                    model.revealInFinder(
                        FileNode(
                            url: URL(fileURLWithPath: item.trashedPath),
                            name: item.name,
                            isDirectory: false,
                            sizeInBytes: 0,
                            children: []
                        )
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(t("Убрать", "Remove")) {
                    model.removeDeletedHistoryItem(item)
                    selected.remove(item.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected.contains(item.id) ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var quickRollbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Снимки отката действий", "Quick Action Rollback Sessions"))
                .font(.headline)
            Text(t(
                "Откат применим только к действиям снижения нагрузки (без удаления файлов).",
                "Rollback is available for load-relief actions only (no file deletion involved)."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(model.quickActionRollbackSessions) { session in
                quickRollbackRow(session)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statusTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func quickRollbackRow(_ session: QuickActionRollbackSession) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.actionTitle)
                    .font(.subheadline.weight(.semibold))
                Text("\(session.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(session.adjustedTargets.count) target(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let rollbackSummary = session.rollbackSummary, !rollbackSummary.isEmpty {
                    Text(rollbackSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if session.canRollback {
                Button(t("Откатить", "Rollback")) {
                    if let summary = model.rollbackQuickActionSession(session) {
                        rollbackMessage = summary
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                GlassPillBadge(
                    title: t("Откат применён", "Rollback Applied"),
                    tint: .green
                )
            }

            Button(t("Убрать", "Remove")) {
                model.removeQuickActionRollbackSession(session)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toggleSelection(_ id: RecentlyDeletedItem.ID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func clearAppliedRollbackSessions() {
        let applied = model.quickActionRollbackSessions.filter { !$0.canRollback }
        for session in applied {
            model.removeQuickActionRollbackSession(session)
        }
    }
}

private enum RecoveryWorkspaceTab: Hashable {
    case overview
    case recentlyDeleted
    case rollback
}
