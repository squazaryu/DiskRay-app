import SwiftUI

struct SmartCareView: View {
    @ObservedObject var model: RootViewModel
    @State private var expandedCategories = Set<String>()
    @State private var selectedItemPaths = Set<String>()
    @State private var newExclusion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            exclusionsPanel

            if model.isSmartScanRunning {
                ProgressView("Analyzing cleanup categories...")
            }

            if model.smartScanCategories.isEmpty, !model.isSmartScanRunning {
                ContentUnavailableView(
                    "No Scan Results",
                    systemImage: "sparkles",
                    description: Text("Run Smart Scan to build a cleanup plan.")
                )
            } else {
                categoriesList
            }
        }
        .padding()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Care")
                    .font(.title2.bold())
                Text("Run one scan to find safe cleanup opportunities.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Run Smart Scan") {
                selectedItemPaths.removeAll()
                model.runSmartScan()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isSmartScanRunning)

            Button("Clean Selected") {
                cleanSelection()
            }
            .buttonStyle(.bordered)
            .disabled(selectedCategoryCount == 0 && selectedItemPaths.isEmpty)
        }
    }

    private var exclusionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exclusions")
                .font(.headline)
            HStack {
                TextField("/path/to/exclude", text: $newExclusion)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let path = newExclusion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !path.isEmpty else { return }
                    model.addSmartExclusion(path)
                    newExclusion = ""
                }
            }
            if !model.smartExclusions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.smartExclusions, id: \.self) { excluded in
                            HStack(spacing: 6) {
                                Text(excluded)
                                    .lineLimit(1)
                                Button {
                                    model.removeSmartExclusion(excluded)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var categoriesList: some View {
        List {
            ForEach(model.smartScanCategories) { category in
                Section {
                    categoryRow(category)
                    if expandedCategories.contains(category.id) {
                        categoryItems(category)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func categoryRow(_ category: SmartCategoryState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { category.isSelected },
                set: { _ in model.toggleSmartCategorySelection(category.id) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(category.result.title)
                    .font(.headline)
                Text(category.result.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(category.result.items.count) items · \(ByteCountFormatter.string(fromByteCount: category.result.totalBytes, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if category.result.isSafeByDefault {
                Text("Safe")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
            }

            Button(expandedCategories.contains(category.id) ? "Hide" : "Preview") {
                toggleExpanded(category.id)
            }
            .buttonStyle(.bordered)
        }
    }

    private func categoryItems(_ category: SmartCategoryState) -> some View {
        ForEach(category.result.items.prefix(30)) { item in
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { selectedItemPaths.contains(item.url.path) },
                    set: { _ in toggleItem(item.url.path) }
                ))
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                    Text(item.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: item.sizeInBytes, countStyle: .file))
                    .font(.caption)
            }
        }
    }

    private var selectedCategoryCount: Int {
        model.smartScanCategories.filter(\.isSelected).count
    }

    private func toggleExpanded(_ id: String) {
        if expandedCategories.contains(id) {
            expandedCategories.remove(id)
        } else {
            expandedCategories.insert(id)
        }
    }

    private func toggleItem(_ path: String) {
        if selectedItemPaths.contains(path) {
            selectedItemPaths.remove(path)
        } else {
            selectedItemPaths.insert(path)
        }
    }

    private func cleanSelection() {
        if !selectedItemPaths.isEmpty {
            let items = model.smartScanCategories
                .flatMap { $0.result.items }
                .filter { selectedItemPaths.contains($0.url.path) }
            selectedItemPaths.removeAll()
            model.cleanSmartItems(items)
            return
        }
        model.cleanSelectedSmartCategories()
    }
}
