import SwiftUI
import AppKit

struct ClutterView: View {
    @StateObject private var model: ClutterViewModel

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashPaths: [String] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?
    @State private var cleanupDiagnostics: [CleanupDiagnosticRow] = []

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: ClutterViewModel(root: rootModel))
    }

    var body: some View {
        VStack(spacing: 10) {
            controls
            controlsToolbar

            if model.isDuplicateScanRunning {
                progressPanel
            }

            Group {
                if model.duplicateGroups.isEmpty, !model.isDuplicateScanRunning {
                    ContentUnavailableView(
                        t("Дубликаты не найдены", "No Duplicates"),
                        systemImage: "square.on.square",
                        description: Text(t(
                            "Запусти скан выбранной цели или домашней папки.",
                            "Run duplicate scan for selected target or Home folder."
                        ))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    duplicateList
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 0)

            if !selectedPaths.isEmpty {
                selectionPanel
            }

            if !cleanupDiagnostics.isEmpty {
                cleanupDiagnosticsPanel
            }
        }
        .padding(12)
        .onAppear { selectRecommendedDuplicates() }
        .onChange(of: groupsSignature) {
            syncSelectionWithExistingFiles()
            if selectedPaths.isEmpty {
                selectRecommendedDuplicates()
            }
        }
        .confirmationDialog(
            t("Переместить выбранные дубликаты в корзину?", "Move selected duplicates to Trash?"),
            isPresented: $showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button(t("Переместить в корзину", "Move to Trash"), role: .destructive) {
                performDuplicateTrash(paths: pendingTrashPaths)
            }
            Button(t("Отмена", "Cancel"), role: .cancel) { pendingTrashPaths = [] }
        }
        .alert(t("Результат очистки дубликатов", "Duplicate Cleanup Result"), isPresented: Binding(
            get: { trashResultMessage != nil },
            set: { if !$0 { trashResultMessage = nil } }
        )) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(trashResultMessage ?? "")
        }
    }

    private var controls: some View {
        ModuleHeaderCard(
            title: t("My Clutter: Точные дубликаты", "My Clutter: Exact Duplicates"),
            subtitle: t(
                "Группы с одинаковым содержимым (SHA-256) и размером файла.",
                "Groups with identical content (SHA-256) and equal file size."
            )
        ) {
            EmptyView()
        }
    }

    private var controlsToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                GlassPillBadge(title: t("Групп \(model.duplicateGroups.count)", "Groups \(model.duplicateGroups.count)"), tint: .blue)
                GlassPillBadge(
                    title: t(
                        "К освобождению \(ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file))",
                        "Reclaimable \(ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file))"
                    ),
                    tint: .green
                )
                GlassPillBadge(
                    title: t(
                        "Выбрано \(selectedPaths.count) · \(ByteCountFormatter.string(fromByteCount: selectedSelectedBytes, countStyle: .file))",
                        "Selected \(selectedPaths.count) · \(ByteCountFormatter.string(fromByteCount: selectedSelectedBytes, countStyle: .file))"
                    ),
                    tint: .orange
                )

                Stepper(value: duplicateMinSizeBinding, in: 1...2_048, step: 1) {
                    Text(t("Мин \(Int(model.duplicateMinSizeMB)) МБ", "Min \(Int(model.duplicateMinSizeMB)) MB"))
                        .frame(minWidth: 120, alignment: .trailing)
                }
                .frame(width: 170)

                Button(t("Скан цели", "Scan Target")) {
                    selectedPaths.removeAll()
                    model.scanDuplicatesInSelectedTarget()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.isDuplicateScanRunning)

                Button(t("Скан Home", "Scan Home")) {
                    selectedPaths.removeAll()
                    model.scanDuplicatesInHome()
                }
                .controlSize(.small)
                .disabled(model.isDuplicateScanRunning)

                if model.isDuplicateScanRunning {
                    Button(t("Отмена", "Cancel")) {
                        model.cancelDuplicateScan()
                    }
                    .controlSize(.small)
                }

                Button(t("Очистить", "Clear")) {
                    selectedPaths.removeAll()
                    model.clearDuplicateResults()
                }
                .controlSize(.small)
                .disabled(model.duplicateGroups.isEmpty && selectedPaths.isEmpty)

                Button(t("Экспорт лога", "Export Ops Log")) {
                    if let url = model.exportOperationLogReport() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        trashResultMessage = t("Лог сохранён:\n\(url.path)", "Ops log exported:\n\(url.path)")
                    } else {
                        trashResultMessage = t("Не удалось сохранить лог.", "Failed to export ops log.")
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var progressPanel: some View {
        HStack(spacing: 10) {
            Text("\(model.duplicateScanProgress.phase): \(model.duplicateScanProgress.visitedFiles.formatted(.number.grouping(.automatic))) file(s)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("•")
                .foregroundStyle(.secondary)
            Text(t(
                "Потенциальных групп: \(model.duplicateScanProgress.candidateGroups.formatted(.number.grouping(.automatic)))",
                "Candidate groups: \(model.duplicateScanProgress.candidateGroups.formatted(.number.grouping(.automatic)))"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("•")
                .foregroundStyle(.secondary)
            Text(model.duplicateScanProgress.currentPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.04, padding: 10)
    }

    private var duplicateList: some View {
        List {
            ForEach(model.duplicateGroups) { group in
                Section {
                    ForEach(group.files) { file in
                        duplicateRow(file, group: group)
                    }
                } header: {
                    HStack {
                        Text(t("\(group.files.count) элементов", "\(group.files.count) items"))
                        Text(t(
                            "По \(ByteCountFormatter.string(fromByteCount: group.sizeInBytes, countStyle: .file))",
                            "Each \(ByteCountFormatter.string(fromByteCount: group.sizeInBytes, countStyle: .file))"
                        ))
                        Spacer()
                        Text(t(
                            "К освобождению \(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))",
                            "Reclaimable \(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))"
                        ))
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func duplicateRow(_ file: DuplicateFile, group: DuplicateGroup) -> some View {
        let path = file.url.path
        let isRecommendedKeep = group.files.first?.url.path == path
        let isProtected = model.isPathProtectedForManualCleanup(path)

        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { selectedPaths.contains(path) },
                set: { isSelected in
                    if isSelected { selectedPaths.insert(path) }
                    else { selectedPaths.remove(path) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(isProtected)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(file.name)
                        .lineLimit(1)
                    if isRecommendedKeep {
                        Text(t("оставить", "keep"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.16), in: Capsule())
                    }
                    if isProtected {
                        Text(t("защищён", "protected"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                    }
                }
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let modifiedAt = file.modifiedAt {
                    Text(modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: file.sizeInBytes, countStyle: .file))
                .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selectedPaths.contains(path) ? Color.accentColor.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button(t("Открыть", "Open")) { NSWorkspace.shared.open(file.url) }
            Button(t("Показать в Finder", "Reveal in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
            Divider()
            Button(selectedPaths.contains(path) ? t("Убрать из выбора", "Remove from Selection") : t("Добавить в выбор", "Add to Selection")) {
                if selectedPaths.contains(path) { selectedPaths.remove(path) }
                else { selectedPaths.insert(path) }
            }
            .disabled(isProtected)
            Button(t("Переместить в корзину", "Move to Trash"), role: .destructive) {
                requestDuplicateTrash(paths: [path])
            }
            .disabled(isProtected)
        }
    }

    private var selectionPanel: some View {
        HStack(spacing: 8) {
            Text(t("Выбрано: \(selectedPaths.count)", "Selected: \(selectedPaths.count)"))
            Text(ByteCountFormatter.string(fromByteCount: selectedSelectedBytes, countStyle: .file))
                .foregroundStyle(.secondary)
            Button(t("Показать первый", "Reveal first")) {
                guard let first = selectedPaths.sorted().first else { return }
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first)])
            }
            Button(t("В корзину", "Move to Trash"), role: .destructive) {
                requestDuplicateTrash(paths: selectedPaths.sorted())
            }
            Button(t("Очистить", "Clear")) {
                selectedPaths.removeAll()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.04, padding: 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var duplicateMinSizeBinding: Binding<Double> {
        Binding(
            get: { model.duplicateMinSizeMB },
            set: { model.duplicateMinSizeMB = $0 }
        )
    }

    private var cleanupDiagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Диагностика удаления", "Cleanup Diagnostics"))
                    .font(.headline)
                Spacer()
                Button(t("Очистить", "Clear")) {
                    cleanupDiagnostics.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Text(t("Файл", "File"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(t("Статус", "Status"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 96, alignment: .leading)
                Text(t("Причина", "Reason"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(cleanupDiagnostics) { row in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.fileName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(row.path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(row.status)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(row.statusColor)
                                .frame(width: 96, alignment: .leading)

                            Text(row.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(6)
            }
            .frame(minHeight: 120, maxHeight: 240)
        }
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.04, padding: 10)
    }

    private var groupsSignature: String {
        model.duplicateGroups
            .map { "\($0.signature):\($0.files.count)" }
            .joined(separator: "|")
    }

    private var selectedSelectedBytes: Int64 {
        selectedPaths.reduce(Int64(0)) { partial, path in
            partial + (fileByPath[path]?.sizeInBytes ?? 0)
        }
    }

    private var totalReclaimableBytes: Int64 {
        model.duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    private var fileByPath: [String: DuplicateFile] {
        var map: [String: DuplicateFile] = [:]
        for group in model.duplicateGroups {
            for file in group.files {
                map[file.url.path] = file
            }
        }
        return map
    }

    private func syncSelectionWithExistingFiles() {
        let existing = Set(fileByPath.keys)
        selectedPaths = selectedPaths.filter { existing.contains($0) && !model.isPathProtectedForManualCleanup($0) }
    }

    private func selectRecommendedDuplicates() {
        let recommended = model.duplicateGroups.flatMap { group in
            Array(group.files.dropFirst().map { $0.url.path })
        }
        selectedPaths = Set(recommended.filter { !model.isPathProtectedForManualCleanup($0) })
    }

    private func requestDuplicateTrash(paths: [String]) {
        guard !paths.isEmpty else { return }
        if model.confirmBeforeDestructiveActions {
            pendingTrashPaths = paths
            showTrashConfirm = true
            return
        }
        performDuplicateTrash(paths: paths)
    }

    private func performDuplicateTrash(paths: [String]) {
        guard !paths.isEmpty else { return }
        let result = model.moveDuplicatePathsToTrash(paths)
        let attempted = Set(paths)
        let skipped = Set(result.skippedProtected)
        let failed = Set(result.failed)
        let movedSet = attempted.subtracting(skipped).subtracting(failed)
        cleanupDiagnostics = buildCleanupDiagnostics(
            attemptedPaths: paths,
            moved: movedSet,
            skipped: skipped,
            failed: failed
        )
        selectedPaths.subtract(movedSet)
        trashResultMessage = model.trashResultMessage(result)
        pendingTrashPaths = []
    }

    private func buildCleanupDiagnostics(
        attemptedPaths: [String],
        moved: Set<String>,
        skipped: Set<String>,
        failed: Set<String>
    ) -> [CleanupDiagnosticRow] {
        let fm = FileManager.default
        return attemptedPaths.map { path in
            if moved.contains(path) {
                return CleanupDiagnosticRow(
                    path: path,
                    status: t("Удалён", "Moved"),
                    statusColor: .green,
                    reason: t("Успешно перемещён в корзину.", "Moved to Trash successfully.")
                )
            }
            if skipped.contains(path) {
                return CleanupDiagnosticRow(
                    path: path,
                    status: t("Пропущен", "Skipped"),
                    statusColor: .orange,
                    reason: t(
                        "Системно-защищённый путь macOS (SIP/TCC).",
                        "System-protected macOS path (SIP/TCC)."
                    )
                )
            }
            if failed.contains(path) {
                let reason: String
                if !fm.fileExists(atPath: path) {
                    reason = t("Файл уже отсутствует на диске.", "File no longer exists.")
                } else if !fm.isDeletableFile(atPath: path) {
                    reason = t(
                        "Нет прав на удаление или файл заблокирован.",
                        "No delete permission or file is locked."
                    )
                } else {
                    reason = t(
                        "Ошибка файловой системы, блокировка процессом или ограничение доступа.",
                        "Filesystem error, in-use lock, or access restriction."
                    )
                }
                return CleanupDiagnosticRow(
                    path: path,
                    status: t("Ошибка", "Failed"),
                    statusColor: .red,
                    reason: reason
                )
            }
            return CleanupDiagnosticRow(
                path: path,
                status: t("Неизвестно", "Unknown"),
                statusColor: .secondary,
                reason: t("Статус операции не определён.", "Operation status is unknown.")
            )
        }
    }

    private var isRussian: Bool {
        model.appLanguage.localeCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }
}

private struct CleanupDiagnosticRow: Identifiable {
    let id = UUID()
    let path: String
    let status: String
    let statusColor: Color
    let reason: String

    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
