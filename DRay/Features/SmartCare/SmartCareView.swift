import SwiftUI

struct SmartCareView: View {
    @ObservedObject var model: RootViewModel
    @State private var expandedCategories = Set<String>()
    @State private var selectedItemPaths = Set<String>()
    @State private var newExclusion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            exclusionsPanel
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.06, padding: 12)

            Group {
                if model.isSmartScanRunning {
                    ProgressView("Analyzing cleanup categories...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                if model.smartScanCategories.isEmpty, !model.isSmartScanRunning {
                    ContentUnavailableView(
                        "No Scan Results",
                        systemImage: "sparkles",
                        description: Text("Run Smart Scan to build a cleanup plan.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    categoriesList
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 0)
        }
        .padding(12)
    }

    private var header: some View {
        ModuleHeaderCard(
            title: "Smart Care",
            subtitle: headerSubtitle
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "Categories \(model.smartScanCategories.count)", tint: .blue)
                    GlassPillBadge(title: "Selected \(selectedCategoryCount)", tint: .green)
                    GlassPillBadge(title: "Items \(selectedItemPaths.count)", tint: .orange)
                }

                HStack(spacing: 8) {
                    Button("Run Full Smart Scan") {
                        selectedItemPaths.removeAll()
                        model.runUnifiedScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.isUnifiedScanRunning)

                    Button("Run Smart Scan") {
                        selectedItemPaths.removeAll()
                        model.runSmartScan()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.isSmartScanRunning || model.isUnifiedScanRunning)

                    Button("Clean Selected") {
                        cleanSelection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedCategoryCount == 0 && selectedItemPaths.isEmpty)
                }

                HStack(spacing: 8) {
                    Button("Select Recommended") {
                        model.selectRecommendedSmartCategories()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.smartScanCategories.isEmpty)

                    Picker("Profile", selection: Binding(
                        get: { model.smartProfile },
                        set: { model.applySmartProfile($0) }
                    )) {
                        ForEach(SmartCleanProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }
        }
    }

    private var exclusionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exclusions")
                    .font(.headline)
                Spacer()
                Text("Applied: \(model.smartExclusions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Min size MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("1", value: $model.smartMinCleanSizeMB, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
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
                            .background(.regularMaterial, in: Capsule())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Common Exclusions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(quickExclusionTargets, id: \.path) { target in
                            let excluded = model.smartExclusions.contains(target.path)
                            Button {
                                model.toggleSmartExclusion(target.path)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: excluded ? "slash.circle.fill" : "plus.circle.fill")
                                        .foregroundStyle(excluded ? Color.orange : Color.green)
                                    Text(target.title)
                                }
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .help(excluded ? "Remove exclusion for \(target.title)" : "Exclude \(target.title) from Smart Scan")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Analyzer Scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.smartAnalyzerOptions) { analyzer in
                            let enabled = !model.smartExcludedAnalyzerKeys.contains(analyzer.key)
                            Button {
                                model.toggleSmartAnalyzerExclusion(analyzer.key)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: enabled ? "checkmark.circle.fill" : "slash.circle.fill")
                                        .foregroundStyle(enabled ? Color.green : Color.orange)
                                    Text(analyzer.title)
                                }
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .help(enabled ? "Analyzer enabled" : "Analyzer excluded")
                        }
                    }
                }
            }
        }
    }

    private var categoriesList: some View {
        List {
            if let summary = model.unifiedScanSummary {
                Section("Unified Scan Summary") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Care: \(summary.smartCareCategories) categories · \(ByteCountFormatter.string(fromByteCount: summary.smartCareBytes, countStyle: .file))")
                        Text("Privacy: \(summary.privacyCategories) categories · \(ByteCountFormatter.string(fromByteCount: summary.privacyBytes, countStyle: .file))")
                        Text("Startup: \(summary.startupEntries) entries · \(ByteCountFormatter.string(fromByteCount: summary.startupBytes, countStyle: .file))")
                        Text("Updated \(summary.finishedAt, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            if !model.smartAnalyzerTelemetry.isEmpty {
                Section("Analyzer Telemetry") {
                    ForEach(model.smartAnalyzerTelemetry) { item in
                        HStack(spacing: 8) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            if item.skipped {
                                GlassPillBadge(title: "Excluded", tint: .orange)
                            } else {
                                GlassPillBadge(title: durationText(item.durationMs), tint: .blue)
                            }
                            Spacer()
                            if !item.skipped {
                                Text("\(item.itemCount) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: item.totalBytes, countStyle: .file))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            ForEach(model.smartScanCategories) { category in
                Section {
                    categoryRow(category)
                    if expandedCategories.contains(category.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Why recommended: \(category.result.recommendationReason)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Why detected: \(category.result.explainability)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.top, 2)
                        categoryItems(category)
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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
                Text("Confidence: \(Int(category.result.confidenceScore * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if category.result.isSafeByDefault {
                GlassPillBadge(title: "Safe", tint: .green)
            }
            GlassPillBadge(
                title: riskTitle(category.result.riskLevel),
                tint: riskColor(category.result.riskLevel)
            )

            Button(expandedCategories.contains(category.id) ? "Hide" : "Preview") {
                toggleExpanded(category.id)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
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
                    Text("Confidence: \(Int(item.confidenceScore * 100))% · \(item.explainability)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: item.sizeInBytes, countStyle: .file))
                    .font(.caption)
            }
            .padding(.vertical, 1)
        }
    }

    private var selectedCategoryCount: Int {
        model.smartScanCategories.filter(\.isSelected).count
    }

    private var quickExclusionTargets: [(title: String, path: String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            ("Desktop", home + "/Desktop"),
            ("Documents", home + "/Documents"),
            ("Downloads", home + "/Downloads"),
            ("iCloud Drive", home + "/Library/Mobile Documents")
        ]
    }

    private func toggleExpanded(_ id: String) {
        if expandedCategories.contains(id) {
            expandedCategories.remove(id)
        } else {
            expandedCategories.insert(id)
        }
    }

    private var headerSubtitle: String {
        let categories = model.smartScanCategories.count
        let selectedCategories = selectedCategoryCount
        let selectedItems = selectedItemPaths.count
        if categories == 0 {
            return "Run one scan to find safe cleanup opportunities."
        }
        return "Found \(categories) categories · selected \(selectedCategories) categories and \(selectedItems) items."
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

    private func riskTitle(_ level: CleanupRiskLevel) -> String {
        switch level {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }

    private func riskColor(_ level: CleanupRiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func durationText(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms) ms" }
        return String(format: "%.1f s", Double(ms) / 1000.0)
    }
}
