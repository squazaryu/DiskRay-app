import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashNodes: [FileNode] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .onChange(of: model.root?.id) {
            selectedPaths.removeAll()
        }
    }

    private var sidebar: some View {
        List {
            permissionsSection
            scanTargetSection
            largestSection
        }
        .overlay {
            if model.isLoading {
                ProgressView("Scanning disk...")
            }
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
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
            Button("Open Full Disk Access") { model.permissions.openFullDiskAccessSettings() }
            Button("Restore") { model.restorePermissions() }
        }
    }

    private var scanTargetSection: some View {
        Section("Scan Target") {
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

    @ViewBuilder
    private var largestSection: some View {
        if let root = model.root {
            Section("Largest") {
                ForEach(root.largestChildren.prefix(20)) { node in
                    largestRow(node)
                }
            }
        }
    }

    private func largestRow(_ node: FileNode) -> some View {
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
        .contentShape(Rectangle())
        .background(model.hoveredPath == node.url.path ? Color.accentColor.opacity(0.12) : .clear)
        .onTapGesture { toggleSelection(node.url.path) }
        .onHover { inside in model.hoveredPath = inside ? node.url.path : nil }
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
                BubbleMapView(root: root, hoveredPath: $model.hoveredPath, selectedPaths: $selectedPaths)
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
        guard let root = model.root else { return [] }
        return root.flattened
            .filter { selectedPaths.contains($0.url.path) }
            .sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }
}
