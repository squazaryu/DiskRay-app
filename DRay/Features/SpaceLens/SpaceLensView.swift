import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashNodes: [FileNode] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?
    @State private var nodeIndex: [String: FileNode] = [:]
    @State private var nodeIndexBuildToken = UUID()
    @State private var bubbleTapMode: BubbleTapMode = .openFolders

    var body: some View {
        VStack(spacing: 10) {
            header
            HStack(alignment: .top, spacing: 12) {
                sidebar
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 420)
                detail
                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.04, shadowOpacity: 0.03, padding: 8)
            }
        }
        .padding(12)
        .onAppear {
            selectedPaths.removeAll()
            model.hoveredPath = nil
            rebuildNodeIndex()
        }
        .onChange(of: model.root?.id) {
            selectedPaths.removeAll()
            rebuildNodeIndex()
        }
        .onDisappear {
            nodeIndexBuildToken = UUID()
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: model.localized(.navSpaceLens),
            subtitle: "\(model.localized(.spaceLensTarget)): \(model.selectedTarget.url.path)"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "\(model.localized(.spaceLensSelected)) \(selectedPaths.count)", tint: .blue)
                    if let root = model.root {
                        GlassPillBadge(title: "\(model.localized(.spaceLensNodes)) \(root.children.count)", tint: .green)
                    }
                    targetPicker

                    Button(model.localized(.spaceLensScan)) { model.scanSelected() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(model.isLoading)

                    Picker(model.localized(.spaceLensTapMode), selection: $bubbleTapMode) {
                        ForEach(BubbleTapMode.allCases) { mode in
                            Text(bubbleTapModeTitle(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)

                    if model.isLoading {
                        Button(model.isPaused ? model.localized(.spaceLensResume) : model.localized(.spaceLensPause)) { model.togglePauseScan() }
                            .controlSize(.small)
                        Button(model.localized(.spaceLensCancel)) { model.cancelScan() }
                            .controlSize(.small)
                    }

                    Button(model.localized(.spaceLensRescan)) { model.rescan() }
                        .controlSize(.small)
                        .disabled(model.lastScannedTarget == nil || model.isLoading)
                }
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard(title: model.localized(.spaceLensPermissions)) {
                    permissionsSection
                }
                sectionCard(title: model.localized(.spaceLensScanTarget)) {
                    scanTargetSection
                }
                if let root = model.root {
                    sectionCard(title: model.localized(.spaceLensLargest)) {
                        largestSection(root: root)
                    }
                }
            }
            .padding(10)
        }
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.04, shadowOpacity: 0.03, padding: 0)
        .overlay {
            if model.isLoading {
                ProgressView(t("Сканирование диска...", "Scanning disk..."))
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.permissions.hasFolderPermission
                 ? model.localized(.spaceLensFolderGranted)
                 : model.localized(.spaceLensFolderDenied))
                .font(.footnote)
                .foregroundStyle(model.permissions.hasFolderPermission ? .green : .orange)

            Text(model.permissions.hasFullDiskAccess
                 ? model.localized(.spaceLensFullDiskGranted)
                 : model.localized(.spaceLensFullDiskDenied))
                .font(.footnote)
                .foregroundStyle(model.permissions.hasFullDiskAccess ? .green : .orange)

            if let permissionHint = model.permissions.permissionHint {
                Text(permissionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if model.permissions.firstLaunchNeedsSetup {
                Text(model.localized(.spaceLensFirstLaunchRequired))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(model.localized(.settingsGrantFolder)) { onChooseFolder() }
                .buttonStyle(.bordered)
            Button(model.localized(.settingsOpenFullDisk)) { model.permissions.openFullDiskAccessSettings() }
                .buttonStyle(.bordered)
            Button(model.localized(.settingsRestore)) { model.restorePermissions() }
                .buttonStyle(.bordered)
        }
    }

    private var scanTargetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(model.selectedTarget.name, systemImage: "externaldrive")
                Spacer()
            }
            .font(.subheadline.weight(.semibold))
            Text(model.selectedTargetPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func largestSection(root: FileNode) -> some View {
        VStack(spacing: 6) {
            ForEach(root.largestChildren.prefix(20)) { node in
                largestRow(node)
            }
        }
    }

    private func largestRow(_ node: FileNode) -> some View {
        Button {
            toggleSelection(node.url.path)
        } label: {
            HStack {
                Image(systemName: selectedPaths.contains(node.url.path) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedPaths.contains(node.url.path) ? Color.accentColor : Color.secondary.opacity(0.4))
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text(node.name)
                    Text(node.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(node.formattedSize)
                    .fontWeight(.semibold)
            }
            .padding(6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        model.hoveredPath == node.url.path
                        ? AnyShapeStyle(Color.accentColor.opacity(0.12))
                        : AnyShapeStyle(.thinMaterial)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                if model.hoveredPath != node.url.path {
                    model.hoveredPath = node.url.path
                }
            } else if model.hoveredPath == node.url.path {
                model.hoveredPath = nil
            }
        }
        .contextMenu {
            Button(model.localized(.spaceLensOpen)) { model.openItem(node) }
            Button(t("Показать в Finder", "Reveal in Finder")) { model.revealInFinder(node) }
            Button(selectedPaths.contains(node.url.path) ? t("Убрать из выбора", "Remove from Selection") : t("Добавить в выбор", "Add to Selection")) {
                toggleSelection(node.url.path)
            }
            Divider()
            Button(model.localized(.spaceLensMoveToTrash), role: .destructive) {
                pendingTrashNodes = [node]
                showTrashConfirm = true
            }
        }
    }

    private var detail: some View {
        Group {
            if let root = model.root {
                BubbleMapView(
                    root: root,
                    hoveredPath: $model.hoveredPath,
                    selectedPaths: $selectedPaths,
                    tapMode: $bubbleTapMode,
                    language: model.appLanguage
                )
            } else {
                emptyState
            }
        }
        .overlay(alignment: .bottomLeading) {
            if model.root != nil {
                bottomPanel
            }
        }
        .confirmationDialog(
            model.localized(.spaceLensTrashDialogTitle),
            isPresented: $showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button(model.localized(.spaceLensTrashDialogAction), role: .destructive) {
                guard !pendingTrashNodes.isEmpty else { return }
                let result = model.moveToTrash(nodes: pendingTrashNodes)
                trashResultMessage = model.trashResultMessage(result)
                pendingTrashNodes = []
                selectedPaths.removeAll()
            }
            Button(model.localized(.commonCancel), role: .cancel) { pendingTrashNodes = [] }
        }
        .alert(model.localized(.spaceLensTrashResultTitle), isPresented: Binding(
            get: { trashResultMessage != nil },
            set: { if !$0 { trashResultMessage = nil } }
        )) {
            Button(model.localized(.commonOK), role: .cancel) {}
        } message: {
            Text(trashResultMessage ?? "")
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                model.localized(.navSpaceLens),
                systemImage: "externaldrive",
                description: Text(model.permissions.firstLaunchNeedsSetup
                                  ? model.localized(.spaceLensEmptyNeedSetup)
                                  : model.localized(.spaceLensEmptyNeedScan))
            )

            HStack(spacing: 12) {
                targetPicker
                Button(model.localized(.spaceLensScan)) { model.scanSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)
            }

            if model.isLoading {
                scanningProgressCard
            }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if model.isLoading || !selectedPaths.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if model.isLoading {
                    Text("\(model.localized(.spaceLensScanning)): \(formattedVisitedItems(model.progress.visitedItems))")
                    Text(model.progress.currentPath)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !selectedPaths.isEmpty {
                    Divider()
                    HStack(spacing: 8) {
                        Text("\(model.localized(.spaceLensSelectedCount)): \(selectedNodes.count)")
                        Button(model.localized(.spaceLensOpen)) {
                            guard let first = selectedNodes.first else { return }
                            model.openItem(first)
                        }
                        Button(model.localized(.spaceLensReveal)) {
                            guard let first = selectedNodes.first else { return }
                            model.revealInFinder(first)
                        }
                        Button(model.localized(.spaceLensMoveToTrash), role: .destructive) {
                            pendingTrashNodes = selectedNodes
                            showTrashConfirm = true
                        }
                        Button(model.localized(.spaceLensClear)) { selectedPaths.removeAll() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial)
            )
            .padding()
        }
    }

    private var scanningProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(model.localized(.spaceLensScanning)): \(formattedVisitedItems(model.progress.visitedItems))")
                .font(.headline)
            Text(model.progress.currentPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 620)
    }

    private var targetPicker: some View {
        Menu {
            Button(model.localized(.spaceLensMacintoshHD)) { model.selectMacDisk() }
            Button(model.localized(.spaceLensHome)) { model.selectHome() }
            Divider()
            Button(model.localized(.spaceLensChooseFolder)) { onChooseFolder() }
        } label: {
            Label(model.selectedTarget.name, systemImage: "folder")
        }
        .controlSize(.small)
    }

    private func bubbleTapModeTitle(_ mode: BubbleTapMode) -> String {
        switch mode {
        case .select:
            return model.localized(.bubbleTapModeSelect)
        case .openFolders:
            return model.localized(.bubbleTapModeOpenFolders)
        }
    }

    private var selectedNodes: [FileNode] {
        return selectedPaths
            .compactMap { nodeIndex[$0] }
            .sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    private func rebuildNodeIndex() {
        guard let root = model.root else {
            nodeIndex = [:]
            return
        }

        let token = UUID()
        nodeIndexBuildToken = token
        let rootSnapshot = root

        DispatchQueue.global(qos: .utility).async {
            let map = buildNodeIndex(root: rootSnapshot)
            DispatchQueue.main.async {
                guard self.nodeIndexBuildToken == token else { return }
                self.nodeIndex = map
            }
        }
    }

    private var isRussian: Bool {
        model.appLanguage.localeCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    private func formattedVisitedItems(_ count: Int) -> String {
        let formatted = count.formatted(.number.grouping(.automatic))
        return isRussian ? "\(formatted) файлов" : "\(formatted) files"
    }
}

private func buildNodeIndex(root: FileNode) -> [String: FileNode] {
    var map: [String: FileNode] = [:]
    var stack: [FileNode] = [root]
    while let node = stack.popLast() {
        map[node.url.path] = node
        stack.append(contentsOf: node.children)
    }
    return map
}
