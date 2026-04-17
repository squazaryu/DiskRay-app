import SwiftUI

struct SearchView: View {
    @StateObject private var model: SearchViewModel
    @State private var selection = Set<FileNode.ID>()
    @State private var presetName = ""
    @State private var pendingDeleteNodes: [FileNode] = []
    @State private var showDeleteConfirm = false
    @State private var resultMessage: String?

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: SearchViewModel(root: rootModel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModuleHeaderCard(
                title: t("Search", "Search"),
                subtitle: t(
                    "Live file intelligence workspace with scope, filters, presets and bulk actions.",
                    "Live file intelligence workspace with scope, filters, presets and bulk actions."
                )
            ) {
                EmptyView()
            }

            searchToolbar
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.10, shadowOpacity: 0.05, padding: 12)

            filtersPanel
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 12)

            if model.search.query.isEmpty {
                ContentUnavailableView(
                    t("Поиск", "Search"),
                    systemImage: "magnifyingglass",
                    description: Text(t("Введи запрос и нажми «Поиск».", "Type query and press Search."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)
            } else {
                resultsPanel
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 8)
            }

            Spacer()
        }
        .padding(12)
        .onChange(of: model.search.results) {
            let valid = Set(model.search.results.map(\.id))
            selection = selection.intersection(valid)
        }
        .confirmationDialog(
            t("Переместить выбранные элементы в корзину?", "Move selected items to Trash?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(t("Переместить в корзину", "Move to Trash"), role: .destructive) {
                let result = model.moveToTrash(nodes: pendingDeleteNodes)
                selection.removeAll()
                pendingDeleteNodes = []
                resultMessage = buildResultMessage(result)
            }
            Button(t("Отмена", "Cancel"), role: .cancel) {
                pendingDeleteNodes = []
            }
        } message: {
            Text(t(
                "\(pendingDeleteNodes.count) элементов будет перемещено в корзину.",
                "\(pendingDeleteNodes.count) item(s) will be moved to Trash."
            ))
        }
        .alert(t("Результат удаления", "Trash Result"), isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private var searchToolbar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(model.searchScopeChoices) { choice in
                        Button {
                            model.selectScope(choice)
                        } label: {
                            HStack {
                                Text(choice.title)
                                Spacer()
                                if isScopeSelected(choice) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(model.activeScopeLabel, systemImage: "externaldrive")
                        .lineLimit(1)
                        .frame(maxWidth: 260, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)

                TextField(t("Поиск по имени или пути...", "Search by name or path..."), text: model.binding(\.query))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.triggerSearch()
                    }

                Button(t("Поиск", "Search")) {
                    model.triggerSearch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if model.search.isLiveRunning {
                    Button(t("Стоп", "Stop")) {
                        model.cancelSearch()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if model.isLoading || model.search.isLiveRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Text(model.activeScopePath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(t("Путь содержит", "Path contains"), text: model.binding(\.pathContains))
                    .textFieldStyle(.roundedBorder)
                TextField(t("Владелец содержит", "Owner contains"), text: model.binding(\.ownerContains))
                    .textFieldStyle(.roundedBorder)
                Text(t("Мин. МБ", "Min MB"))
                    .font(.caption.weight(.semibold))
                TextField("0", value: model.binding(\.minSizeMB), format: .number)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                Toggle(t("Папки", "Dirs"), isOn: model.binding(\.onlyDirectories))
                    .toggleStyle(.checkbox)
                Toggle(t("Файлы", "Files"), isOn: model.binding(\.onlyFiles))
                    .toggleStyle(.checkbox)
                TextField(t("Имя пресета", "Preset name"), text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button(t("Сохранить пресет", "Save Preset")) {
                    let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    model.savePreset(named: name)
                    presetName = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Menu(t("Пресеты", "Presets")) {
                    ForEach(model.search.presets) { preset in
                        Button(preset.name) { model.applyPreset(preset) }
                    }
                    if !model.search.presets.isEmpty {
                        Divider()
                        ForEach(model.search.presets) { preset in
                            Button("\(t("Удалить", "Delete")) \(preset.name)") { model.deletePreset(preset) }
                        }
                    }
                }
                .controlSize(.small)
            }
            .font(.caption)

            HStack(spacing: 8) {
                Toggle("Regex", isOn: model.binding(\.useRegex))
                    .toggleStyle(.checkbox)
                Text(t("Глубина", "Depth"))
                TextField("0", value: model.binding(\.depthMin), format: .number)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                Text("..")
                TextField("64", value: model.binding(\.depthMax), format: .number)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                Text(t("Изменён ≤ дней", "Modified ≤ days"))
                TextField("0", value: model.binding(\.modifiedWithinDays), format: .number)
                    .frame(width: 65)
                    .textFieldStyle(.roundedBorder)
                Toggle(t("Исключать корзину", "Exclude Trash"), isOn: model.binding(\.excludeTrash))
                    .toggleStyle(.checkbox)
                Toggle(t("Скрытые", "Hidden"), isOn: model.binding(\.includeHidden))
                    .toggleStyle(.checkbox)
                Toggle(t("Внутри пакетов", "Package Contents"), isOn: model.binding(\.includePackageContents))
                    .toggleStyle(.checkbox)
                Picker(t("Тип", "Type"), selection: model.binding(\.nodeType)) {
                    Text(t("Любой", "Any")).tag(QueryEngine.SearchNodeType.any)
                    Text(t("Файлы", "Files")).tag(QueryEngine.SearchNodeType.file)
                    Text(t("Папки", "Folders")).tag(QueryEngine.SearchNodeType.directory)
                    Text(t("Приложения", "Apps")).tag(QueryEngine.SearchNodeType.package)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                Spacer()
            }
            .font(.caption)
        }
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Выбрано: \(selection.count)", "Selected: \(selection.count)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(t("Найдено: \(model.search.results.count)", "Found: \(model.search.results.count)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(t("Выбрать все", "Select All")) {
                    selection = Set(model.search.results.map(\.id))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.search.results.isEmpty)
                Button(t("Снять выбор", "Clear Selection")) {
                    selection.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selection.isEmpty)
                Button(t("Показать", "Reveal")) {
                    guard let first = selectedNodes().first else { return }
                    model.revealInFinder(first)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selection.isEmpty)
                Button(t("Удалить выбранное", "Trash Selected")) {
                    requestTrashConfirmation(for: selectedNodes())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selection.isEmpty)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(t("Имя", "Name"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(t("Размер", "Size"))
                        .frame(width: 120, alignment: .trailing)
                    Text(t("Путь", "Path"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 4) {
                        if model.search.results.isEmpty && model.search.isLiveRunning {
                            ForEach(0..<8, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(height: 34)
                            }
                        } else if model.search.results.isEmpty {
                            Text(t("Ничего не найдено", "No files found"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(model.search.results) { node in
                                resultRow(node)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
            )
        }
    }

    private func resultRow(_ node: FileNode) -> some View {
        let isSelected = selection.contains(node.id)
        return HStack(spacing: 12) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(node.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(node.formattedSize)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(node.url.path)
                .lineLimit(1)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(node.id)
        }
        .onTapGesture(count: 2) {
            model.openItem(node)
        }
        .contextMenu {
            Button(t("Показать в Finder", "Reveal in Finder")) { model.revealInFinder(node) }
            Button(t("Открыть", "Open")) { model.openItem(node) }
            Button(t("В корзину", "Move to Trash")) {
                requestTrashConfirmation(for: [node])
            }
        }
    }

    private func toggleSelection(_ id: FileNode.ID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func selectedNodes() -> [FileNode] {
        model.search.results.filter { selection.contains($0.id) }
    }

    private func buildResultMessage(_ result: TrashOperationResult) -> String {
        model.trashResultMessage(result)
    }

    private func requestTrashConfirmation(for nodes: [FileNode]) {
        guard !nodes.isEmpty else { return }
        if model.confirmBeforeDestructiveActions {
            pendingDeleteNodes = nodes
            showDeleteConfirm = true
            return
        }
        let result = model.moveToTrash(nodes: nodes)
        selection.subtract(nodes.map(\.id))
        pendingDeleteNodes = []
        resultMessage = buildResultMessage(result)
    }

    private func isScopeSelected(_ choice: SearchScopeChoice) -> Bool {
        switch model.search.scopeMode {
        case .startupDisk:
            return choice.mode == .startupDisk
        case .selectedTarget:
            return choice.mode == .selectedTarget
        case .customPath:
            return choice.mode == .customPath && choice.path == model.search.customScopePath
        }
    }

    private var isRussian: Bool {
        model.appLanguage.localeCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }
}
