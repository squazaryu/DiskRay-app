import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashNodes: [FileNode] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?
    @State private var nodeIndex: [String: FileNode] = [:]
    @State private var bubbleTapMode: BubbleTapMode = .openFolders

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 420)
            detail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                .glassSurface(cornerRadius: 18, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 8)
        }
        .padding(8)
        .onAppear {
            selectedPaths.removeAll()
            model.hoveredPath = nil
            rebuildNodeIndex()
        }
        .onChange(of: model.root?.id) {
            selectedPaths.removeAll()
            rebuildNodeIndex()
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard(title: "Permissions") {
                    permissionsSection
                }
                sectionCard(title: "Scan Target") {
                    scanTargetSection
                }
                if let root = model.root {
                    sectionCard(title: "Largest") {
                        largestSection(root: root)
                    }
                }
            }
            .padding(10)
        }
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.12, shadowOpacity: 0.08, padding: 0)
        .overlay {
            if model.isLoading {
                ProgressView("Scanning disk...")
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.permissions.hasFolderPermission
                 ? "Folder access granted for selected target."
                 : "Folder access is not granted for current target.")
                .font(.footnote)
                .foregroundStyle(model.permissions.hasFolderPermission ? .green : .orange)

            if let permissionHint = model.permissions.permissionHint {
                Text(permissionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Grant Folder Access") { onChooseFolder() }
                .buttonStyle(.bordered)
            Button("Open Full Disk Access") { model.permissions.openFullDiskAccessSettings() }
                .buttonStyle(.bordered)
            Button("Restore") { model.restorePermissions() }
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
            Button("Open") { model.openItem(node) }
            Button("Reveal in Finder") { model.revealInFinder(node) }
            Button(selectedPaths.contains(node.url.path) ? "Remove from Selection" : "Add to Selection") {
                toggleSelection(node.url.path)
            }
            Divider()
            Button("Move to Trash", role: .destructive) {
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
                    tapMode: $bubbleTapMode
                )
            } else {
                emptyState
            }
        }
        .toolbar { toolbarContent }
        .overlay(alignment: .bottomLeading) { bottomPanel }
        .confirmationDialog(
            "Move selected item(s) to Trash?",
            isPresented: $showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                guard !pendingTrashNodes.isEmpty else { return }
                let result = model.moveToTrash(nodes: pendingTrashNodes)
                trashResultMessage = "Moved: \(result.moved), Skipped protected: \(result.skippedProtected.count), Failed: \(result.failed.count)"
                pendingTrashNodes = []
                selectedPaths.removeAll()
            }
            Button("Cancel", role: .cancel) { pendingTrashNodes = [] }
        }
        .alert("Trash Result", isPresented: Binding(
            get: { trashResultMessage != nil },
            set: { if !$0 { trashResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Space Lens",
                systemImage: "externaldrive",
                description: Text(model.permissions.firstLaunchNeedsSetup
                                  ? "Grant access and choose folder for first scan."
                                  : "Choose a target and start scan.")
            )

            HStack(spacing: 12) {
                targetPicker
                Button("Scan") { model.scanSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            targetPicker
            Button("Scan") { model.scanSelected() }
                .disabled(model.isLoading)
            Picker("Tap Mode", selection: $bubbleTapMode) {
                ForEach(BubbleTapMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            if model.isLoading {
                Button(model.isPaused ? "Resume" : "Pause") { model.togglePauseScan() }
                Button("Cancel") { model.cancelScan() }
            }
            Button("Rescan") { model.rescan() }
                .disabled(model.lastScannedTarget == nil || model.isLoading)
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if model.isLoading || !selectedPaths.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if model.isLoading {
                    Text("Scanning: \(model.progress.visitedItems) items")
                    Text(model.progress.currentPath)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !selectedPaths.isEmpty {
                    Divider()
                    HStack(spacing: 8) {
                        Text("Selected: \(selectedNodes.count)")
                        Button("Open") {
                            guard let first = selectedNodes.first else { return }
                            model.openItem(first)
                        }
                        Button("Reveal") {
                            guard let first = selectedNodes.first else { return }
                            model.revealInFinder(first)
                        }
                        Button("Move to Trash", role: .destructive) {
                            pendingTrashNodes = selectedNodes
                            showTrashConfirm = true
                        }
                        Button("Clear") { selectedPaths.removeAll() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding()
        }
    }

    private var targetPicker: some View {
        Menu {
            Button("Macintosh HD") { model.selectMacDisk() }
            Button("Home") { model.selectHome() }
            Divider()
            Button("Choose folder...") { onChooseFolder() }
        } label: {
            Label(model.selectedTarget.name, systemImage: "folder")
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
        var map: [String: FileNode] = [:]
        var stack: [FileNode] = [root]
        while let node = stack.popLast() {
            map[node.url.path] = node
            stack.append(contentsOf: node.children)
        }
        nodeIndex = map
    }
}
