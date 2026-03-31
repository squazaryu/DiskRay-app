import SwiftUI
import AppKit

struct ClutterView: View {
    @ObservedObject var model: RootViewModel

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashPaths: [String] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            controls

            if model.isDuplicateScanRunning {
                progressPanel
            }

            Group {
                if model.duplicateGroups.isEmpty, !model.isDuplicateScanRunning {
                    ContentUnavailableView(
                        "No Duplicates",
                        systemImage: "square.on.square",
                        description: Text("Run duplicate scan for selected target or Home folder.")
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
            "Move selected duplicates to Trash?",
            isPresented: $showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                let result = model.moveDuplicatePathsToTrash(pendingTrashPaths)
                let attempted = Set(pendingTrashPaths)
                let skipped = Set(result.skippedProtected)
                let failed = Set(result.failed)
                let movedSet = attempted.subtracting(skipped).subtracting(failed)
                selectedPaths.subtract(movedSet)
                trashResultMessage = "Moved: \(result.moved), Skipped protected: \(result.skippedProtected.count), Failed: \(result.failed.count)"
                pendingTrashPaths = []
            }
            Button("Cancel", role: .cancel) { pendingTrashPaths = [] }
        }
        .alert("Duplicate Cleanup Result", isPresented: Binding(
            get: { trashResultMessage != nil },
            set: { if !$0 { trashResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(trashResultMessage ?? "")
        }
    }

    private var controls: some View {
        ModuleHeaderCard(
            title: "My Clutter: Exact Duplicates",
            subtitle: "Groups with identical content (SHA-256) and equal file size."
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "Groups \(model.duplicateGroups.count)", tint: .blue)
                    GlassPillBadge(
                        title: "Reclaimable \(ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file))",
                        tint: .green
                    )
                    GlassPillBadge(
                        title: "Selected \(selectedPaths.count) · \(ByteCountFormatter.string(fromByteCount: selectedSelectedBytes, countStyle: .file))",
                        tint: .orange
                    )
                }

                HStack(spacing: 8) {
                    Stepper(value: $model.duplicateMinSizeMB, in: 1...2_048, step: 1) {
                        Text("Min \(Int(model.duplicateMinSizeMB)) MB")
                            .frame(minWidth: 120, alignment: .trailing)
                    }
                    .frame(width: 170)

                    Button("Scan Target") {
                        selectedPaths.removeAll()
                        model.scanDuplicatesInSelectedTarget()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.isDuplicateScanRunning)

                    Button("Scan Home") {
                        selectedPaths.removeAll()
                        model.scanDuplicatesInHome()
                    }
                    .controlSize(.small)
                    .disabled(model.isDuplicateScanRunning)

                    if model.isDuplicateScanRunning {
                        Button("Cancel") {
                            model.cancelDuplicateScan()
                        }
                        .controlSize(.small)
                    }

                    Button("Clear") {
                        selectedPaths.removeAll()
                        model.clearDuplicateResults()
                    }
                    .controlSize(.small)
                    .disabled(model.duplicateGroups.isEmpty && selectedPaths.isEmpty)
                }
            }
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(model.duplicateScanProgress.phase): \(model.duplicateScanProgress.visitedFiles) file(s)")
                .font(.subheadline.weight(.semibold))
            Text("Candidate groups: \(model.duplicateScanProgress.candidateGroups)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.duplicateScanProgress.currentPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
                        Text("\(group.files.count) items")
                        Text("Each \(ByteCountFormatter.string(fromByteCount: group.sizeInBytes, countStyle: .file))")
                        Spacer()
                        Text("Reclaimable \(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))")
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

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(file.name)
                        .lineLimit(1)
                    if isRecommendedKeep {
                        Text("keep")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.16), in: Capsule())
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
            Button("Open") { NSWorkspace.shared.open(file.url) }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
            Divider()
            Button(selectedPaths.contains(path) ? "Remove from Selection" : "Add to Selection") {
                if selectedPaths.contains(path) { selectedPaths.remove(path) }
                else { selectedPaths.insert(path) }
            }
            Button("Move to Trash", role: .destructive) {
                pendingTrashPaths = [path]
                showTrashConfirm = true
            }
        }
    }

    private var selectionPanel: some View {
        HStack(spacing: 8) {
            Text("Selected: \(selectedPaths.count)")
            Text(ByteCountFormatter.string(fromByteCount: selectedSelectedBytes, countStyle: .file))
                .foregroundStyle(.secondary)
            Button("Reveal first") {
                guard let first = selectedPaths.sorted().first else { return }
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first)])
            }
            Button("Move to Trash", role: .destructive) {
                pendingTrashPaths = selectedPaths.sorted()
                showTrashConfirm = true
            }
            Button("Clear") {
                selectedPaths.removeAll()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.04, padding: 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        selectedPaths = selectedPaths.filter { existing.contains($0) }
    }

    private func selectRecommendedDuplicates() {
        let recommended = model.duplicateGroups.flatMap { group in
            Array(group.files.dropFirst().map { $0.url.path })
        }
        selectedPaths = Set(recommended)
    }
}
