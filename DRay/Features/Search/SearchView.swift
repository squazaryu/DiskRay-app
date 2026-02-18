import SwiftUI

struct SearchView: View {
    @ObservedObject var model: RootViewModel
    @State private var selection = Set<FileNode.ID>()
    @State private var presetName = ""
    @State private var pendingDeleteNodes: [FileNode] = []
    @State private var showDeleteConfirm = false
    @State private var resultMessage: String?
    @State private var showRestoreFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search by name or path...", text: $model.searchQuery)
                    .textFieldStyle(.roundedBorder)

                if model.isLoading {
                    ProgressView()
                }
            }

            HStack {
                TextField("Path contains", text: $model.pathContains)
                    .textFieldStyle(.roundedBorder)
                Text("Min MB")
                TextField("0", value: $model.minSizeMB, format: .number)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                Toggle("Dirs", isOn: $model.onlyDirectories)
                Toggle("Files", isOn: $model.onlyFiles)
                TextField("Preset name", text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("Save Preset") {
                    let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    model.saveCurrentSearchPreset(named: name)
                    presetName = ""
                }
                Menu("Presets") {
                    ForEach(model.searchPresets) { preset in
                        Button(preset.name) { model.applySearchPreset(preset) }
                    }
                    if !model.searchPresets.isEmpty {
                        Divider()
                        ForEach(model.searchPresets) { preset in
                            Button("Delete \(preset.name)") { model.deletePreset(preset) }
                        }
                    }
                }
            }
            .font(.caption)

            if model.searchQuery.isEmpty {
                ContentUnavailableView("Search Index", systemImage: "magnifyingglass", description: Text("Type query after scan completes."))
            } else {
                HStack {
                    Text("Selected: \(selection.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reveal") {
                        guard let first = selectedNodes().first else { return }
                        model.revealInFinder(first)
                    }
                    .disabled(selection.isEmpty)
                    Button("Trash Selected") {
                        pendingDeleteNodes = selectedNodes()
                        showDeleteConfirm = !pendingDeleteNodes.isEmpty
                    }
                    .disabled(selection.isEmpty)
                }
                Table(model.searchResults, selection: $selection) {
                    TableColumn("Name") { node in
                        Text(node.name)
                    }
                    TableColumn("Size") { node in
                        Text(node.formattedSize)
                    }
                    TableColumn("Path") { node in
                        Text(node.url.path)
                            .lineLimit(1)
                    }
                }
                .contextMenu(forSelectionType: FileNode.ID.self) { ids in
                    if let id = ids.first, let node = model.searchResults.first(where: { $0.id == id }) {
                        Button("Reveal in Finder") { model.revealInFinder(node) }
                        Button("Open") { model.openItem(node) }
                        Button("Move to Trash") {
                            pendingDeleteNodes = [node]
                            showDeleteConfirm = true
                        }
                    }
                } primaryAction: { ids in
                    if let id = ids.first, let node = model.searchResults.first(where: { $0.id == id }) {
                        model.openItem(node)
                    }
                }
            }

            if !model.recentlyDeleted.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently Deleted")
                        .font(.headline)

                    List {
                        ForEach(model.recentlyDeleted.prefix(30)) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(item.originalPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.deletedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Restore") {
                                    if !model.restoreDeletedItem(item) {
                                        showRestoreFailed = true
                                    }
                                }
                                Button("Reveal") {
                                    model.revealInFinder(FileNode(
                                        url: URL(fileURLWithPath: item.trashedPath),
                                        name: item.name,
                                        isDirectory: false,
                                        sizeInBytes: 0,
                                        children: []
                                    ))
                                }
                                Button("Remove") {
                                    model.removeDeletedHistoryItem(item)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 150, maxHeight: 220)
                }
            }

            Spacer()
        }
        .padding()
        .confirmationDialog(
            "Move selected items to Trash?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                let result = model.moveToTrash(nodes: pendingDeleteNodes)
                selection.removeAll()
                pendingDeleteNodes = []
                resultMessage = buildResultMessage(result)
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteNodes = []
            }
        } message: {
            Text("\(pendingDeleteNodes.count) item(s) will be moved to Trash.")
        }
        .alert("Trash Result", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .alert("Restore failed", isPresented: $showRestoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not restore this item. It may be removed from Trash or blocked by permissions.")
        }
    }

    private func selectedNodes() -> [FileNode] {
        model.searchResults.filter { selection.contains($0.id) }
    }

    private func buildResultMessage(_ result: TrashOperationResult) -> String {
        var parts: [String] = ["Moved: \(result.moved)"]
        if !result.skippedProtected.isEmpty { parts.append("Skipped protected: \(result.skippedProtected.count)") }
        if !result.failed.isEmpty { parts.append("Failed: \(result.failed.count)") }
        return parts.joined(separator: ", ")
    }
}
