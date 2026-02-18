import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void
    @State private var pendingTrashNode: FileNode?
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?

    var body: some View {
        NavigationSplitView {
            List {
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

                    Button("Grant Folder Access") {
                        onChooseFolder()
                    }
                    Button("Open Full Disk Access") {
                        model.permissions.openFullDiskAccessSettings()
                    }
                    Button("Restore") {
                        model.restorePermissions()
                    }
                }

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

                if let root = model.root {
                    Section("Largest") {
                        ForEach(root.largestChildren.prefix(20)) { node in
                            HStack {
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
                            .onHover { inside in
                                model.hoveredPath = inside ? node.url.path : nil
                            }
                        }
                    }
                }
            }
            .overlay {
                if model.isLoading {
                    ProgressView("Scanning disk...")
                }
            }
        } detail: {
            Group {
                if let root = model.root {
                    BubbleMapView(
                        root: root,
                        hoveredPath: $model.hoveredPath,
                        onOpen: { node in model.openItem(node) },
                        onReveal: { node in model.revealInFinder(node) },
                        onRequestTrash: { node in
                            pendingTrashNode = node
                            showTrashConfirm = true
                        }
                    )
                } else {
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
                            Button("Scan") {
                                model.scanSelected()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isLoading)
                        }
                    }
                }
            }
            .toolbar {
                targetPicker
                Button("Scan") {
                    model.scanSelected()
                }
                .disabled(model.isLoading)
                if model.isLoading {
                    Button(model.isPaused ? "Resume" : "Pause") {
                        model.togglePauseScan()
                    }
                    Button("Cancel") {
                        model.cancelScan()
                    }
                }

                Button("Rescan") {
                    model.rescan()
                }
                .disabled(model.lastScannedTarget == nil || model.isLoading)
            }
            .overlay(alignment: .bottomLeading) {
                if model.isLoading {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scanning: \(model.progress.visitedItems) items")
                        Text(model.progress.currentPath)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
                }
            }
            .confirmationDialog(
                "Move selected item to Trash?",
                isPresented: $showTrashConfirm,
                titleVisibility: .visible
            ) {
                Button("Move to Trash", role: .destructive) {
                    guard let pendingTrashNode else { return }
                    let result = model.moveToTrash(nodes: [pendingTrashNode])
                    trashResultMessage = "Moved: \(result.moved), Skipped protected: \(result.skippedProtected.count), Failed: \(result.failed.count)"
                    self.pendingTrashNode = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingTrashNode = nil
                }
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
    }

    private var targetPicker: some View {
        Menu {
            Button("Macintosh HD") {
                model.selectMacDisk()
            }
            Button("Home") {
                model.selectHome()
            }
            Divider()
            Button("Choose folder...") {
                onChooseFolder()
            }
        } label: {
            Label(model.selectedTarget.name, systemImage: "folder")
        }
    }
}
