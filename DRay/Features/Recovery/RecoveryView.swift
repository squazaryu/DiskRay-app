import SwiftUI

struct RecoveryView: View {
    @ObservedObject var model: RootViewModel
    @State private var selected = Set<RecentlyDeletedItem.ID>()
    @State private var showRestoreFailed = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Восстановление", "Recovery"))
                        .font(.title2.bold())
                    Text(t(
                        "Раздел хранит историю файлов, удалённых через DRay, и позволяет вернуть их из Корзины.",
                        "This section stores items deleted via DRay and lets you restore them from Trash."
                    ))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Восстановить выбранные", "Restore Selected")) {
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
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }

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
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.recentlyDeleted) { item in
                            recoveryRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
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

    private func toggleSelection(_ id: RecentlyDeletedItem.ID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}
