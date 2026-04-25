import SwiftUI
import AppKit

struct ClutterView: View {
    @StateObject private var model: ClutterViewModel

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashPaths: [String] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?
    @State private var cleanupDiagnostics: [CleanupDiagnosticRow] = []
    @State private var workspaceTab: ClutterWorkspaceTab = .overview

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: ClutterViewModel(root: rootModel))
    }

    var body: some View {
        VStack(spacing: 10) {
            controls
            controlsToolbar
            workspaceNavigation
            statusStrip

            if model.isDuplicateScanRunning {
                progressPanel
            }

            switch workspaceTab {
            case .overview:
                overviewWorkspace
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 12)
            case .groups:
                groupsWorkspace
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 0)
            case .diagnostics:
                diagnosticsWorkspace
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 12)
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

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text(t("Обзор", "Overview")).tag(ClutterWorkspaceTab.overview)
                Text(t("Группы", "Groups")).tag(ClutterWorkspaceTab.groups)
                Text(t("Диагностика", "Diagnostics")).tag(ClutterWorkspaceTab.diagnostics)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 2)
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            statusTile(
                title: t("Группы", "Groups"),
                value: "\(model.duplicateGroups.count)",
                tint: .blue
            )
            statusTile(
                title: t("К освобождению", "Reclaimable"),
                value: ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file),
                tint: .green
            )
            statusTile(
                title: t("Выбрано", "Selected"),
                value: "\(selectedPaths.count)",
                tint: selectedPaths.isEmpty ? .secondary : .orange
            )
            statusTile(
                title: t("Диагностика", "Diagnostics"),
                value: "\(cleanupDiagnostics.count)",
                tint: cleanupDiagnostics.isEmpty ? .secondary : .purple
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var controlsToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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

    private var overviewWorkspace: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                summaryCard(
                    title: t("Группы", "Groups"),
                    value: "\(model.duplicateGroups.count)",
                    subtitle: t("Группы с идентичным содержимым", "Groups with identical content")
                )
                summaryCard(
                    title: t("Выбрано", "Selected"),
                    value: "\(selectedPaths.count)",
                    subtitle: t("Файлы к удалению", "Files selected for cleanup")
                )
                summaryCard(
                    title: t("К освобождению", "Reclaimable"),
                    value: ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file),
                    subtitle: t("Потенциал очистки", "Potential cleanup")
                )
                summaryCard(
                    title: t("Выбрано (объём)", "Selected Size"),
                    value: ByteCountFormatter.string(fromByteCount: selectedSelectedBytes, countStyle: .file),
                    subtitle: t("Текущий выбор", "Current selection")
                )
            }

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
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Рекомендация", "Focus"))
                        .font(.subheadline.weight(.semibold))
                    Text(t(
                        "Перейди во вкладку «Группы», проверь рекомендованный выбор и выполни очистку пакетно.",
                        "Open Groups workspace, verify recommended selection, then run batch cleanup."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var groupsWorkspace: some View {
        VStack(spacing: 8) {
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
                if !selectedPaths.isEmpty {
                    selectionPanel
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    private var diagnosticsWorkspace: some View {
        Group {
            if cleanupDiagnostics.isEmpty {
                ContentUnavailableView(
                    t("Диагностика очистки пуста", "No Cleanup Diagnostics"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(t(
                        "После очистки дубликатов здесь появится детальная диагностика операций.",
                        "Run duplicate cleanup to see detailed diagnostics here."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cleanupDiagnosticsPanel
            }
        }
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

private enum ClutterWorkspaceTab: Hashable {
    case overview
    case groups
    case diagnostics
}
