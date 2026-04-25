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
            commandStrip
            workspaceNavigation
            statusStrip

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
            EmptyView()
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
        .padding(.horizontal, 2)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                summaryCard(
                    title: t("Удалённые", "Recently Deleted"),
                    value: "\(model.recentlyDeleted.count)",
                    subtitle: t("Файлы в истории удаления", "Items in deleted history")
                )
                summaryCard(
                    title: t("Выбрано", "Selected"),
                    value: "\(selected.count)",
                    subtitle: t("Кандидаты на восстановление", "Candidates for restore")
                )
                summaryCard(
                    title: t("Rollback", "Rollback"),
                    value: "\(model.quickActionRollbackSessions.count)",
                    subtitle: t("Сессии отката действий", "Rollback sessions")
                )
                summaryCard(
                    title: t("Готово к откату", "Rollback Ready"),
                    value: "\(model.quickActionRollbackSessions.filter(\.canRollback).count)",
                    subtitle: t("Не применённые сессии", "Sessions not yet applied")
                )
            }

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
