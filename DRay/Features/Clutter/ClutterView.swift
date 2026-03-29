import SwiftUI
import AppKit

struct ClutterView: View {
    @ObservedObject var model: RootViewModel

    @State private var selectedPaths = Set<String>()
    @State private var pendingTrashPaths: [String] = []
    @State private var showTrashConfirm = false
    @State private var trashResultMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            controls

            if model.isDuplicateScanRunning {
                progressPanel
            }

            if model.duplicateGroups.isEmpty, !model.isDuplicateScanRunning {
                ContentUnavailableView(
                    "No Duplicates",
                    systemImage: "square.on.square",
                    description: Text("Run duplicate scan for selected target or Home folder.")
                )
            } else {
                duplicateList
            }

            if !selectedPaths.isEmpty {
                selectionPanel
            }
        }
        .padding()
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Clutter: Exact Duplicates")
                    .font(.headline)
                Text("Groups with identical content (SHA-256) and equal file size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
            .disabled(model.isDuplicateScanRunning)

            Button("Scan Home") {
                selectedPaths.removeAll()
                model.scanDuplicatesInHome()
            }
            .disabled(model.isDuplicateScanRunning)

            if model.isDuplicateScanRunning {
                Button("Cancel") {
                    model.cancelDuplicateScan()
                }
            }

            Button("Clear") {
                selectedPaths.removeAll()
                model.clearDuplicateResults()
            }
            .disabled(model.duplicateGroups.isEmpty && selectedPaths.isEmpty)
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
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
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
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
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
