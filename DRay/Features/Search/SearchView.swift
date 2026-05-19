import SwiftUI

struct SearchView: View {
    @StateObject private var model: SearchViewModel
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    @State private var selection = Set<String>()
    @State private var presetName = ""
    @State private var pendingDeleteNodes: [FileNode] = []
    @State private var showDeleteConfirm = false
    @State private var resultMessage: String?
    @State private var workspaceTab: SearchWorkspaceTab = .results
    @State private var resultLayout: SearchResultsLayout = .table
    @State private var resultSort: SearchResultSort = .sizeDescending
    @State private var resultsQuickFilter = ""
    @State private var expandedTreeNodes = Set<String>()
    @State private var treeSortColumn: SearchTreeSortColumn = .name
    @State private var treeSortAscending = true

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: SearchViewModel(root: rootModel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.sectionSpacing) {
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
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.10, shadowOpacity: 0.05, padding: layoutMetrics.cardSpacing)
            workspaceNavigation
            statusStrip

            Group {
                switch workspaceTab {
                case .query:
                    queryWorkspace
                case .results:
                    resultsWorkspace
                }
            }

            Spacer()
        }
        .padding(layoutMetrics.cardSpacing)
        .onChange(of: model.search.results) {
            let valid = Set(model.search.results.map(pathKey(for:)))
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

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text(t("Запрос и фильтры", "Query & Filters")).tag(SearchWorkspaceTab.query)
                Text(t("Результаты", "Results")).tag(SearchWorkspaceTab.results)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 2)
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            DRayCompactInfoTile(
                title: t("Область", "Scope"),
                value: model.activeScopeLabel,
                subtitle: t("active target", "active target"),
                icon: "scope",
                tint: .blue
            )
            DRayCompactInfoTile(
                title: t("Найдено", "Found"),
                value: "\(model.search.results.count)",
                subtitle: t("matching items", "matching items"),
                icon: "doc.text.magnifyingglass",
                tint: .green,
                progress: min(1, Double(model.search.results.count) / 200)
            )
            DRayCompactInfoTile(
                title: t("Выбрано", "Selected"),
                value: "\(selection.count)",
                subtitle: t("bulk actions", "bulk actions"),
                icon: "checkmark.circle",
                tint: selection.isEmpty ? .secondary : .orange,
                progress: model.search.results.isEmpty ? 0 : Double(selection.count) / Double(model.search.results.count)
            )
            DRayCompactInfoTile(
                title: t("Режим", "Mode"),
                value: localizedExecutionMode(model.search.mode),
                subtitle: t("search engine", "search engine"),
                icon: "bolt.horizontal.circle",
                tint: .purple
            )
        }
    }

    private var queryWorkspace: some View {
        VStack(alignment: .leading, spacing: 10) {
            filtersPanel
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: layoutMetrics.cardSpacing)

            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        DRayIconBadge(icon: "line.3.horizontal.decrease.circle", tint: .blue, size: 30)
                        Text(t("Search Scope", "Search Scope"))
                            .font(.headline)
                        Spacer()
                    }
                    Text(model.activeScopePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    DRayProgressBar(value: model.search.results.isEmpty ? 0.08 : min(1, Double(model.search.results.count) / 200), tint: .blue, height: 6)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(layoutMetrics.cardSpacing)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)

                VStack(alignment: .leading, spacing: 8) {
                    DRayActionRow(
                        title: t("Run Search", "Run Search"),
                        subtitle: t("Apply query, scope and filters.", "Apply query, scope and filters."),
                        icon: "magnifyingglass",
                        tint: .blue,
                        actionTitle: t("Search", "Search")
                    ) { model.triggerSearch() }
                    DRayActionRow(
                        title: t("Open Results", "Open Results"),
                        subtitle: t("Review and bulk-manage matches.", "Review and bulk-manage matches."),
                        icon: "list.bullet.rectangle",
                        tint: .green,
                        actionTitle: t("Open", "Open")
                    ) { workspaceTab = .results }
                }
                .frame(width: 330, alignment: .topLeading)
                .frame(minHeight: 120, alignment: .topLeading)
                .padding(layoutMetrics.cardSpacing)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
            }
        }
    }

    private var resultsWorkspace: some View {
        Group {
            if model.search.query.isEmpty {
                ContentUnavailableView(
                    t("Поиск", "Search"),
                    systemImage: "magnifyingglass",
                    description: Text(t("Введи запрос и нажми «Поиск».", "Type query and press Search."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)
            } else {
                VStack(spacing: 8) {
                    resultsActionStrip
                    resultsPanel
                }
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: layoutMetrics.bottomStripVerticalPadding)
            }
        }
    }

    private var searchToolbar: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.bottomStripVerticalPadding) {
            HStack(spacing: layoutMetrics.cardSpacing) {
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

                Picker("", selection: model.binding(\.mode)) {
                    Text(t("Fast", "Fast")).tag(SearchExecutionMode.live)
                    Text(t("Deep", "Deep")).tag(SearchExecutionMode.deep)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

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
        VStack(alignment: .leading, spacing: layoutMetrics.bottomStripVerticalPadding) {
            HStack(spacing: layoutMetrics.bottomStripVerticalPadding) {
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

            HStack(spacing: layoutMetrics.bottomStripVerticalPadding) {
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

    private var resultsActionStrip: some View {
        HStack {
            Text(t("Показано: \(displayedResults.count) из \(model.search.results.count)", "Shown: \(displayedResults.count) of \(model.search.results.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $resultLayout) {
                Image(systemName: "tablecells").tag(SearchResultsLayout.table)
                Image(systemName: "list.bullet.indent").tag(SearchResultsLayout.tree)
                Image(systemName: "square.grid.2x2").tag(SearchResultsLayout.grid)
            }
            .pickerStyle(.segmented)
            .frame(width: 132)
            .help(t("Режим отображения результатов", "Result view mode"))
            TextField(t("Фильтр в результатах", "Filter shown results"), text: $resultsQuickFilter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            Picker("", selection: $resultSort) {
                ForEach(SearchResultSort.allCases) { option in
                    Text(localizedSortTitle(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            Spacer()
                Menu(t("Выбор", "Selection")) {
                    Button(t("Выбрать показанные", "Select Shown")) {
                        selectShownItems()
                    }
                Button(t("Выбрать файлы", "Select Files")) {
                    selectShownFiles()
                }
                Button(t("Выбрать папки", "Select Folders")) {
                    selectShownFolders()
                }
                    Button(t("Инвертировать выбор", "Invert Selection")) {
                        invertShownSelection()
                    }
                    Divider()
                    Button(t("Показать выбранные в текущем фильтре", "Keep Selected in Current Filter")) {
                        resultsQuickFilter = selectedFilterToken()
                    }
                    .disabled(selection.isEmpty)
                }
                .controlSize(.small)
                .disabled(displayedResults.isEmpty)
            Button(t("В корзину показанные", "Trash Shown")) {
                requestTrashConfirmation(for: displayedResults)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(displayedResults.isEmpty)
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
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t(
                    "Выбрано: \(selection.count) · в текущем фильтре: \(selectedDisplayedCount)",
                    "Selected: \(selection.count) · in current filter: \(selectedDisplayedCount)"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(t("Scope: \(model.activeScopePath)", "Scope: \(model.activeScopePath)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                switch resultLayout {
                case .table:
                    tableResultsPanel
                case .tree:
                    treeResultsPanel
                case .grid:
                    gridResultsPanel
                }
            }
        }
    }

    private var tableResultsPanel: some View {
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
            .padding(.horizontal, layoutMetrics.cardSpacing)
            .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    resultsRowsContent(style: .table)
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

    private var treeResultsPanel: some View {
        VStack(spacing: 0) {
            treeColumnHeader
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !hierarchicalResults.nodes.isEmpty {
                        treeRootSummaryRow(hierarchicalResults)
                    }

                    if hierarchicalResults.truncatedCount > 0 {
                        Label(
                            t(
                                "Tree mode ограничен первыми \(hierarchicalResults.sourceCount) элементами (ещё \(hierarchicalResults.truncatedCount) скрыто).",
                                "Tree mode is limited to first \(hierarchicalResults.sourceCount) items (\(hierarchicalResults.truncatedCount) more hidden)."
                            ),
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }

                    if hierarchicalResults.nodes.isEmpty && model.search.isLiveRunning {
                        ForEach(0..<8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 34)
                        }
                    } else if hierarchicalResults.nodes.isEmpty {
                        Text(t("Ничего не найдено", "No files found"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(hierarchicalResults.nodes) { node in
                            treeNodeRow(node, depth: 0)
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
        )
    }

    private var treeColumnHeader: some View {
        HStack(spacing: 12) {
            treeSortButton(title: t("Имя", "Name"), column: .name, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            treeSortButton(title: t("Тип", "Kind"), column: .kind, alignment: .leading)
                .frame(width: 150, alignment: .leading)
            treeSortButton(title: t("Изменён", "Modified"), column: .modified, alignment: .leading)
                .frame(width: 165, alignment: .leading)
            treeSortButton(title: t("Размер", "Size"), column: .size, alignment: .trailing)
                .frame(width: 110, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(.regularMaterial)
    }

    private func treeSortButton(title: String, column: SearchTreeSortColumn, alignment: Alignment) -> some View {
        Button {
            setTreeSort(column)
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing {
                    Spacer(minLength: 0)
                }
                Text(title)
                if treeSortColumn == column {
                    Image(systemName: treeSortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                if alignment == .leading {
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var gridResultsPanel: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 8, alignment: .topLeading)],
                spacing: 8
            ) {
                resultsRowsContent(style: .grid)
            }
            .padding(8)
        }
        .frame(maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private func resultsRowsContent(style: SearchResultsLayout) -> some View {
        if displayedResults.isEmpty && model.search.isLiveRunning {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: style == .grid ? 92 : 34)
            }
        } else if displayedResults.isEmpty {
            Text(t("Ничего не найдено", "No files found"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)
        } else {
            ForEach(displayedResults) { node in
                switch style {
                case .table:
                    resultRow(node)
                case .tree:
                    compactResultRow(node)
                case .grid:
                    gridResultCard(node)
                }
            }
        }
    }

    private func resultRow(_ node: FileNode) -> some View {
        let isSelected = selection.contains(pathKey(for: node))
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
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(node)
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

    private func compactResultRow(_ node: FileNode) -> some View {
        let isSelected = selection.contains(pathKey(for: node))
        return HStack(spacing: 10) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .lineLimit(1)
                    .font(.subheadline.weight(.medium))
                Text(node.url.path)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(node.formattedSize)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(node)
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

    private func gridResultCard(_ node: FileNode) -> some View {
        let isSelected = selection.contains(pathKey(for: node))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .lineLimit(1)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
            }
            Text(node.url.path)
                .lineLimit(2)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(node.formattedSize)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(node)
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

    private func treeNodeRow(_ node: SearchHierarchyNode, depth: Int) -> AnyView {
        if node.children.isEmpty {
            return treeLeafRow(node)
        }

        return AnyView(
            DisclosureGroup(
                isExpanded: treeDisclosureBinding(for: node.path, defaultExpanded: depth < 2)
            ) {
                ForEach(node.children) { child in
                    treeNodeRow(child, depth: depth + 1)
                }
            } label: {
                treeBranchLabel(node)
            }
        )
    }

    private func treeDisclosureBinding(for path: String, defaultExpanded: Bool) -> Binding<Bool> {
        Binding(
            get: { expandedTreeNodes.contains(path) || (defaultExpanded && !expandedTreeNodes.contains(collapsedMarker(for: path))) },
            set: { expanded in
                if expanded {
                    expandedTreeNodes.insert(path)
                    expandedTreeNodes.remove(collapsedMarker(for: path))
                } else {
                    expandedTreeNodes.remove(path)
                    expandedTreeNodes.insert(collapsedMarker(for: path))
                }
            }
        )
    }

    private func collapsedMarker(for path: String) -> String {
        "__collapsed__\(path)"
    }

    private func treeBranchLabel(_ node: SearchHierarchyNode) -> some View {
        let meta = metadata(forPath: node.path, isDirectoryHint: true)
        let isSelected = node.matchPaths.allSatisfy { selection.contains($0) } && !node.matchPaths.isEmpty
        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(node.name)
                    .lineLimit(1)
                Text("· \(node.matchPaths.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(meta.kind)
                .lineLimit(1)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(meta.modifiedText)
                .lineLimit(1)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 165, alignment: .leading)
            Text(ByteCountFormatter.string(fromByteCount: node.aggregateMatchSize, countStyle: .file))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleTreeBranchSelection(node)
        }
        .contextMenu {
            Button(t("Выбрать поддерево", "Select Subtree Matches")) {
                selection.formUnion(node.matchPaths)
            }
            Button(t("Снять выбор поддерева", "Deselect Subtree Matches")) {
                selection.subtract(node.matchPaths)
            }
            Divider()
            Button(t("Показать в Finder", "Reveal in Finder")) {
                model.revealInFinder(
                    FileNode(
                        url: URL(fileURLWithPath: node.path),
                        name: node.name,
                        isDirectory: true,
                        sizeInBytes: 0,
                        children: []
                    )
                )
            }
        }
    }

    private func treeRootSummaryRow(_ result: SearchHierarchyResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.activeScopePath)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(t(
                    "\(result.sourceCount) совпадений собрано в дерево · выбранные ветки удаляют только найденные элементы.",
                    "\(result.sourceCount) matches grouped into a tree · branch selection only targets matched items."
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(t("Выбрать дерево", "Select Tree")) {
                selection.formUnion(result.nodes.flatMap(\.matchPaths))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func treeLeafRow(_ node: SearchHierarchyNode) -> AnyView {
        guard let match = node.match else {
            return AnyView(EmptyView())
        }
        let meta = metadata(forPath: match.url.standardizedFileURL.path, isDirectoryHint: match.isDirectory)
        let isSelected = selection.contains(pathKey(for: match))
        return AnyView(
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: match.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text(match.name)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(meta.kind)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                Text(meta.modifiedText)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 165, alignment: .leading)
                Text(match.formattedSize)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding(.horizontal, layoutMetrics.cardSpacing)
            .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(match)
            }
            .onTapGesture(count: 2) {
                model.openItem(match)
            }
            .contextMenu {
                Button(t("Показать в Finder", "Reveal in Finder")) { model.revealInFinder(match) }
                Button(t("Открыть", "Open")) { model.openItem(match) }
                Button(t("В корзину", "Move to Trash")) {
                    requestTrashConfirmation(for: [match])
                }
            }
        )
    }

    private func toggleTreeBranchSelection(_ node: SearchHierarchyNode) {
        let keys = node.matchPaths
        guard !keys.isEmpty else { return }
        let allSelected = keys.allSatisfy { selection.contains($0) }
        if allSelected {
            selection.subtract(keys)
        } else {
            selection.formUnion(keys)
        }
    }

    private func setTreeSort(_ column: SearchTreeSortColumn) {
        if treeSortColumn == column {
            treeSortAscending.toggle()
            return
        }
        treeSortColumn = column
        switch column {
        case .name, .kind:
            treeSortAscending = true
        case .modified, .size:
            treeSortAscending = false
        }
    }

    private func metadata(forPath path: String, isDirectoryHint: Bool) -> SearchDisplayMetadata {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey, .localizedTypeDescriptionKey]
        let values = try? url.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory ?? isDirectoryHint
        let kind = values?.localizedTypeDescription
            ?? (isDirectory ? t("Папка", "Folder") : t("Файл", "File"))
        let modifiedDate = values?.contentModificationDate
        return SearchDisplayMetadata(
            kind: kind,
            modifiedDate: modifiedDate,
            modifiedText: modifiedDate?.formatted(date: .abbreviated, time: .shortened) ?? "—"
        )
    }

    private func toggleSelection(_ node: FileNode) {
        let key = pathKey(for: node)
        if selection.contains(key) {
            selection.remove(key)
        } else {
            selection.insert(key)
        }
    }

    private func selectedNodes() -> [FileNode] {
        model.search.results.filter { selection.contains(pathKey(for: $0)) }
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
        selection.subtract(nodes.map(pathKey(for:)))
        pendingDeleteNodes = []
        resultMessage = buildResultMessage(result)
    }

    private func pathKey(for node: FileNode) -> String {
        node.url.standardizedFileURL.path
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

    private func localizedExecutionMode(_ mode: SearchExecutionMode) -> String {
        switch mode {
        case .live:
            return t("Fast", "Fast")
        case .deep:
            return t("Deep", "Deep")
        }
    }

    private func localizedSortTitle(_ sort: SearchResultSort) -> String {
        switch sort {
        case .sizeDescending:
            return t("Размер ↓", "Size ↓")
        case .sizeAscending:
            return t("Размер ↑", "Size ↑")
        case .nameAscending:
            return t("Имя A→Z", "Name A→Z")
        case .pathAscending:
            return t("Путь A→Z", "Path A→Z")
        }
    }

    private var displayedResults: [FileNode] {
        let filtered = applyQuickFilter(to: model.search.results)
        return sortResults(filtered)
    }

    private var selectedDisplayedCount: Int {
        displayedResults.filter { selection.contains(pathKey(for: $0)) }.count
    }

    private var hierarchicalResults: SearchHierarchyResult {
        buildHierarchy(from: displayedResults)
    }

    private func applyQuickFilter(to nodes: [FileNode]) -> [FileNode] {
        let filter = resultsQuickFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !filter.isEmpty else { return nodes }
        return nodes.filter { node in
            let path = node.url.path.lowercased()
            return node.name.lowercased().contains(filter) || path.contains(filter)
        }
    }

    private func sortResults(_ nodes: [FileNode]) -> [FileNode] {
        switch resultSort {
        case .sizeDescending:
            return nodes.sorted { lhs, rhs in
                if lhs.sizeInBytes == rhs.sizeInBytes {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.sizeInBytes > rhs.sizeInBytes
            }
        case .sizeAscending:
            return nodes.sorted { lhs, rhs in
                if lhs.sizeInBytes == rhs.sizeInBytes {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.sizeInBytes < rhs.sizeInBytes
            }
        case .nameAscending:
            return nodes.sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        case .pathAscending:
            return nodes.sorted { lhs, rhs in
                lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
            }
        }
    }

    private func buildHierarchy(from matches: [FileNode]) -> SearchHierarchyResult {
        let maxTreeMatches = 5_000
        let source = Array(matches.prefix(maxTreeMatches))
        let truncatedCount = max(0, matches.count - source.count)
        let rootPath = normalizedRootPath(model.activeScopePath)
        let rootName = rootPath == "/" ? "/" : URL(fileURLWithPath: rootPath).lastPathComponent
        let root = SearchHierarchyDraftNode(path: rootPath, name: rootName, isDirectory: true)

        for match in source {
            let matchPath = match.url.standardizedFileURL.path
            let components = relativePathComponents(for: matchPath, rootPath: rootPath)
            if components.isEmpty {
                root.match = match
                root.isDirectory = match.isDirectory
                continue
            }

            var current = root
            var currentPath = rootPath
            for (index, component) in components.enumerated() {
                currentPath = appendPathComponent(component, to: currentPath)
                let isLeaf = index == components.count - 1
                let child = current.children[currentPath] ?? SearchHierarchyDraftNode(
                    path: currentPath,
                    name: component,
                    isDirectory: true
                )
                if isLeaf {
                    child.match = match
                    child.isDirectory = match.isDirectory
                } else {
                    child.isDirectory = true
                }
                current.children[currentPath] = child
                current = child
            }
        }

        let nodes = root.children.values
            .map(collapseHierarchy(_:))
            .sorted(by: hierarchyNodeSort(lhs:rhs:))

        return SearchHierarchyResult(
            nodes: nodes,
            sourceCount: source.count,
            truncatedCount: truncatedCount
        )
    }

    private func normalizedRootPath(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardized == "/" { return "/" }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }

    private func relativePathComponents(for fullPath: String, rootPath: String) -> [String] {
        if rootPath == "/" {
            return fullPath
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        }

        guard fullPath.hasPrefix(rootPath) else {
            return fullPath
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        }
        let suffix = String(fullPath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !suffix.isEmpty else { return [] }
        return suffix.split(separator: "/").map(String.init)
    }

    private func appendPathComponent(_ component: String, to parent: String) -> String {
        if parent == "/" {
            return "/\(component)"
        }
        return "\(parent)/\(component)"
    }

    private func collapseHierarchy(_ node: SearchHierarchyDraftNode) -> SearchHierarchyNode {
        let collapsedChildren = node.children.values
            .map(collapseHierarchy(_:))
            .sorted(by: hierarchyNodeSort(lhs:rhs:))

        var matchPaths: [String] = []
        if let match = node.match {
            matchPaths.append(pathKey(for: match))
        }
        for child in collapsedChildren where !child.matchPaths.isEmpty {
            matchPaths.append(contentsOf: child.matchPaths)
        }

        let ownSize = node.match?.sizeInBytes ?? 0
        let aggregateMatchSize = collapsedChildren.reduce(ownSize) { partialResult, child in
            partialResult + child.aggregateMatchSize
        }

        return SearchHierarchyNode(
            path: node.path,
            name: node.name,
            isDirectory: node.isDirectory,
            match: node.match,
            children: collapsedChildren,
            matchPaths: matchPaths,
            aggregateMatchSize: aggregateMatchSize
        )
    }

    private func hierarchyNodeSort(lhs: SearchHierarchyNode, rhs: SearchHierarchyNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }

        let ordering: ComparisonResult
        switch treeSortColumn {
        case .name:
            ordering = lhs.name.localizedStandardCompare(rhs.name)
        case .kind:
            let leftKind = metadata(forPath: lhs.path, isDirectoryHint: lhs.isDirectory).kind
            let rightKind = metadata(forPath: rhs.path, isDirectoryHint: rhs.isDirectory).kind
            ordering = leftKind.localizedStandardCompare(rightKind)
        case .modified:
            let leftDate = metadata(forPath: lhs.path, isDirectoryHint: lhs.isDirectory).modifiedDate ?? .distantPast
            let rightDate = metadata(forPath: rhs.path, isDirectoryHint: rhs.isDirectory).modifiedDate ?? .distantPast
            if leftDate == rightDate {
                ordering = lhs.name.localizedStandardCompare(rhs.name)
            } else {
                ordering = leftDate < rightDate ? .orderedAscending : .orderedDescending
            }
        case .size:
            if lhs.aggregateMatchSize == rhs.aggregateMatchSize {
                ordering = lhs.name.localizedStandardCompare(rhs.name)
            } else {
                ordering = lhs.aggregateMatchSize < rhs.aggregateMatchSize ? .orderedAscending : .orderedDescending
            }
        }

        if ordering == .orderedSame {
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
        return treeSortAscending ? (ordering == .orderedAscending) : (ordering == .orderedDescending)
    }

    private func selectShownItems() {
        selection.formUnion(displayedResults.map(pathKey(for:)))
    }

    private func selectShownFiles() {
        selection.formUnion(displayedResults.filter { !$0.isDirectory }.map(pathKey(for:)))
    }

    private func selectShownFolders() {
        selection.formUnion(displayedResults.filter(\.isDirectory).map(pathKey(for:)))
    }

    private func invertShownSelection() {
        let shownKeys = displayedResults.map(pathKey(for:))
        for key in shownKeys {
            if selection.contains(key) {
                selection.remove(key)
            } else {
                selection.insert(key)
            }
        }
    }

    private func selectedFilterToken() -> String {
        guard let first = selectedNodes().first else { return resultsQuickFilter }
        return first.name
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
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum SearchWorkspaceTab: Hashable {
    case query
    case results
}

private enum SearchResultsLayout: Hashable {
    case table
    case tree
    case grid
}

private enum SearchResultSort: String, CaseIterable, Identifiable {
    case sizeDescending
    case sizeAscending
    case nameAscending
    case pathAscending

    var id: String { rawValue }
}

private enum SearchTreeSortColumn: Hashable {
    case name
    case kind
    case modified
    case size
}

private struct SearchDisplayMetadata {
    let kind: String
    let modifiedDate: Date?
    let modifiedText: String
}

private struct SearchHierarchyResult {
    let nodes: [SearchHierarchyNode]
    let sourceCount: Int
    let truncatedCount: Int
}

private struct SearchHierarchyNode: Identifiable {
    let path: String
    let name: String
    let isDirectory: Bool
    let match: FileNode?
    let children: [SearchHierarchyNode]
    let matchPaths: [String]
    let aggregateMatchSize: Int64

    var id: String { path }
}

private final class SearchHierarchyDraftNode {
    let path: String
    let name: String
    var isDirectory: Bool
    var match: FileNode?
    var children: [String: SearchHierarchyDraftNode] = [:]

    init(path: String, name: String, isDirectory: Bool) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
    }
}
