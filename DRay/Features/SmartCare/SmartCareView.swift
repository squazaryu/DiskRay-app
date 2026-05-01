import SwiftUI

struct SmartCareView: View {
    @StateObject private var model: SmartCareViewModel
    @State private var expandedCategories = Set<String>()
    @State private var selectedItemPaths = Set<String>()
    @State private var newExclusion = ""
    @State private var workspaceTab: SmartCareWorkspaceTab = .overview

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: SmartCareViewModel(root: rootModel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            workspaceNavigation

            if model.smartCare.isScanRunning {
                scanProgressBanner
            }

            Group {
                switch workspaceTab {
                case .overview:
                    ScrollView(.vertical, showsIndicators: true) {
                        smartOverview
                    }
                case .categories:
                    categoriesWorkspace
                case .exclusions:
                    ScrollView(.vertical, showsIndicators: true) {
                        exclusionsPanel
                    }
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: workspaceTab == .categories ? 0 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    @ViewBuilder
    private var categoriesWorkspace: some View {
        if model.smartCare.categories.isEmpty, !model.smartCare.isScanRunning {
            ContentUnavailableView(
                "No Scan Results",
                systemImage: "sparkles",
                description: Text("Run Smart Scan to build a cleanup plan.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                categoriesActionStrip
                categoriesList
            }
        }
    }

    private var smartOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            smartCareHero
            safeCleanupGrid

            if !model.smartCare.analyzerTelemetry.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analyzer telemetry")
                        .font(.subheadline.weight(.semibold))
                    ForEach(model.smartCare.analyzerTelemetry.prefix(6)) { item in
                        HStack(spacing: 8) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            if item.skipped {
                                GlassPillBadge(title: "Excluded", tint: .orange)
                            } else {
                                Text("\(item.itemCount) items")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                GlassPillBadge(title: durationText(item.durationMs), tint: .blue)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(12)
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)
            }
        }
    }

    private var smartCareHero: some View {
        HStack(alignment: .center, spacing: 18) {
            DRayLiquidStatusRing(
                icon: model.smartCare.isScanRunning ? "magnifyingglass" : "heart",
                tint: .blue,
                size: 100
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(model.smartCare.isScanRunning ? "SMART CARE SCAN" : "SMART CARE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                Text(model.smartCare.isScanRunning ? "Scanning your Mac..." : smartCareStatusTitle)
                    .font(.system(size: 26, weight: .semibold))
                    .lineLimit(1)
                Text(model.smartCare.isScanRunning ? "DRay is checking cleanup categories and safe recommendations." : smartCareStatusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    GlassPillBadge(title: "Safe & reversible", tint: .green)
                    GlassPillBadge(title: model.smartCare.profile.title, tint: .purple)
                    GlassPillBadge(title: "\(selectedCategoryCount) selected", tint: selectedCategoryCount > 0 ? .blue : .secondary)
                }
            }

            Spacer(minLength: 10)

            DRayDonutChartView(
                segments: smartCategorySegments,
                centerTitle: smartPotentialSize,
                centerSubtitle: "potential",
                lineWidth: 16
            )
            .frame(width: 132, height: 132)
        }
        .padding(14)
        .glassSurface(cornerRadius: 22, strokeOpacity: 0.11, shadowOpacity: 0.08, padding: 0)
    }

    private var safeCleanupGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Safe Cleanup Categories")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(model.smartCare.categories.prefix(6)) { category in
                        smartCategoryCard(category)
                    }
                    if model.smartCare.categories.isEmpty {
                        ContentUnavailableView(
                            "No scan results",
                            systemImage: "sparkles",
                            description: Text("Run Smart Care to find safe cleanup opportunities.")
                        )
                        .frame(minHeight: 150)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text("Action Center")
                    .font(.headline)
                actionCenterRow("Select recommended", systemImage: "checkmark.circle", enabled: !model.smartCare.categories.isEmpty) {
                    selectedItemPaths.removeAll()
                    model.selectRecommendedSmartCategories()
                }
                actionCenterRow("Review categories", systemImage: "list.bullet.rectangle", enabled: true) {
                    workspaceTab = .categories
                }
                actionCenterRow("Clean selection", systemImage: "trash", enabled: selectedCategoryCount > 0 || !selectedItemPaths.isEmpty) {
                    cleanSelection()
                }
                Button {
                    selectedItemPaths.removeAll()
                    model.cleanRecommendedSmartCategories()
                } label: {
                    Label("Run Smart Care", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(model.smartCare.isScanRunning || model.smartCare.categories.isEmpty)
            }
            .frame(width: 250, alignment: .topLeading)
            .padding(12)
            .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)
        }
    }

    private func smartCategoryCard(_ category: SmartCategoryState) -> some View {
        Button {
            toggleExpanded(category)
            workspaceTab = .categories
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DRayIconBadge(
                        icon: categoryIcon(for: category),
                        tint: riskColor(category.result.riskLevel),
                        size: 32
                    )
                    Spacer()
                    GlassPillBadge(title: category.result.isSafeByDefault ? "Ready" : riskTitle(category.result.riskLevel), tint: riskColor(category.result.riskLevel))
                }
                Text(category.result.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline) {
                    Text(ByteCountFormatter.string(fromByteCount: category.result.totalBytes, countStyle: .file))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Spacer(minLength: 6)
                    Text("\(category.result.items.count) items")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                DRayProgressBar(value: categoryShare(category), tint: riskColor(category.result.riskLevel), height: 6)
                Text(category.result.recommendationReason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func heroMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func actionCenterRow(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(enabled ? Color.blue : Color.secondary)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var scanProgressBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .frame(width: 14, height: 14)
            Text("Analyzing cleanup categories...")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func summaryCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var header: some View {
        ModuleHeaderCard(
            title: "Smart Care",
            subtitle: headerSubtitle
        ) {
            compactSmartActions
        }
    }

    private var compactSmartActions: some View {
        HStack(spacing: 8) {
            profileMenu
            Button("Run") {
                selectedItemPaths.removeAll()
                model.runSmartScan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.smartCare.isScanRunning || model.isUnifiedScanRunning)

            Menu {
                Button("Run Full Smart Scan") {
                    selectedItemPaths.removeAll()
                    model.runUnifiedScan()
                }
                .disabled(model.isUnifiedScanRunning)

                Button("Quick Clean Recommended") {
                    selectedItemPaths.removeAll()
                    model.cleanRecommendedSmartCategories()
                }
                .disabled(model.smartCare.isScanRunning || model.smartCare.categories.isEmpty)

                Divider()

                Button("Select Recommended") {
                    selectedItemPaths.removeAll()
                    model.selectRecommendedSmartCategories()
                }
                .disabled(model.smartCare.categories.isEmpty)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private var smartCommandStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("Profile")
                        .foregroundStyle(.secondary)
                    profileMenu
                }

                Button("Run") {
                    selectedItemPaths.removeAll()
                    model.runSmartScan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.smartCare.isScanRunning || model.isUnifiedScanRunning)

                Menu {
                    Button("Run Full Smart Scan") {
                        selectedItemPaths.removeAll()
                        model.runUnifiedScan()
                    }
                    .disabled(model.isUnifiedScanRunning)

                    Button("Quick Clean Recommended") {
                        selectedItemPaths.removeAll()
                        model.cleanRecommendedSmartCategories()
                    }
                    .disabled(model.smartCare.isScanRunning || model.smartCare.categories.isEmpty)

                    Divider()

                    Button("Select Recommended") {
                        selectedItemPaths.removeAll()
                        model.selectRecommendedSmartCategories()
                    }
                    .disabled(model.smartCare.categories.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text("Overview").tag(SmartCareWorkspaceTab.overview)
                Text("Categories").tag(SmartCareWorkspaceTab.categories)
                Text("Exclusions").tag(SmartCareWorkspaceTab.exclusions)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            Spacer(minLength: 8)
        }
        .padding(6)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.08, shadowOpacity: 0.03, padding: 0)
    }

    private var smartStatusStrip: some View {
        HStack(spacing: 8) {
            statusTile(
                title: "Categories",
                value: "\(model.smartCare.categories.count)",
                tint: .blue
            )
            statusTile(
                title: "Selected",
                value: "\(selectedCategoryCount)",
                tint: selectedCategoryCount > 0 ? .green : .secondary
            )
            statusTile(
                title: "Items",
                value: "\(selectedItemPaths.count)",
                tint: selectedItemPaths.isEmpty ? .secondary : .orange
            )
            statusTile(
                title: "Profile",
                value: model.smartCare.profile.title,
                tint: .purple
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var categoriesActionStrip: some View {
        HStack(spacing: 8) {
            GlassPillBadge(title: "Selected categories \(selectedCategoryCount)", tint: .blue)
            GlassPillBadge(title: "Selected items \(selectedItemPaths.count)", tint: .orange)

            Spacer(minLength: 8)

            Button("Select Recommended") {
                selectedItemPaths.removeAll()
                model.selectRecommendedSmartCategories()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.smartCare.categories.isEmpty)

            Button("Clean Selection") {
                cleanSelection()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedCategoryCount == 0 && selectedItemPaths.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private var profileMenu: some View {
        Menu {
            ForEach(SmartCleanProfile.allCases) { profile in
                Button {
                    model.applySmartProfile(profile)
                } label: {
                    if profile == model.smartCare.profile {
                        Label(profile.title, systemImage: "checkmark")
                    } else {
                        Text(profile.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.smartCare.profile.title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .frame(minWidth: 126, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var exclusionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exclusions")
                    .font(.headline)
                Spacer()
                Text("Applied: \(model.smartCare.exclusions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Min size MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("1", value: model.minCleanSizeMBBinding, format: .number)
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
            if !model.smartCare.exclusions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.smartCare.exclusions, id: \.self) { excluded in
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
                            let excluded = model.smartCare.exclusions.contains(target.path)
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
                            let enabled = !model.smartCare.excludedAnalyzerKeys.contains(analyzer.key)
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
            if !model.smartCare.analyzerTelemetry.isEmpty {
                Section("Analyzer Telemetry") {
                    ForEach(model.smartCare.analyzerTelemetry) { item in
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
            ForEach(model.smartCare.categories) { category in
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
                set: { isSelected in
                    setCategorySelection(category, isSelected: isSelected)
                }
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
                toggleExpanded(category)
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
        model.smartCare.categories.filter(\.isSelected).count
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

    private func toggleExpanded(_ category: SmartCategoryState) {
        if expandedCategories.contains(category.id) {
            expandedCategories.remove(category.id)
        } else {
            expandedCategories.insert(category.id)
            if category.isSelected {
                selectAllItems(in: category)
            }
        }
    }

    private func setCategorySelection(_ category: SmartCategoryState, isSelected: Bool) {
        guard category.isSelected != isSelected else { return }
        model.toggleSmartCategorySelection(category.id)
        if isSelected {
            if expandedCategories.contains(category.id) {
                selectAllItems(in: category)
            }
        } else {
            deselectAllItems(in: category)
        }
    }

    private func selectAllItems(in category: SmartCategoryState) {
        selectedItemPaths.formUnion(category.result.items.map { $0.url.path })
    }

    private func deselectAllItems(in category: SmartCategoryState) {
        selectedItemPaths.subtract(category.result.items.map { $0.url.path })
    }

    private var headerSubtitle: String {
        let categories = model.smartCare.categories.count
        if categories == 0 {
            return "Run one scan to find safe cleanup opportunities."
        }
        return "Found \(categories) cleanup categories."
    }

    private var smartCareStatusTitle: String {
        if model.smartCare.categories.isEmpty {
            return "Ready to scan"
        }
        if selectedCategoryCount == 0 {
            return "Review recommendations"
        }
        return "Ready to clean"
    }

    private var smartCareStatusSubtitle: String {
        if model.smartCare.categories.isEmpty {
            return "DRay will look for safe cleanup opportunities and performance improvements."
        }
        if selectedCategoryCount == 0 {
            return "Choose recommended categories or inspect details before cleanup."
        }
        return "Selected categories are prepared for reversible cleanup."
    }

    private var smartPotentialSize: String {
        ByteCountFormatter.string(fromByteCount: smartPotentialBytes, countStyle: .file)
    }

    private var smartPotentialBytes: Int64 {
        model.smartCare.categories.reduce(Int64(0)) { partial, category in
            partial + category.result.totalBytes
        }
    }

    private var maxSmartCategoryBytes: Int64 {
        max(model.smartCare.categories.map { $0.result.totalBytes }.max() ?? 1, 1)
    }

    private var smartPalette: [Color] {
        [.blue, .teal, .purple, .orange, .green, .pink]
    }

    private var smartCategorySegments: [DRayDonutSegment] {
        model.smartCare.categories.prefix(6).enumerated().map { index, category in
            DRayDonutSegment(
                title: category.result.title,
                value: Double(max(category.result.totalBytes, 0)),
                color: smartPalette[index % smartPalette.count]
            )
        }
    }

    private func categoryShare(_ category: SmartCategoryState) -> Double {
        Double(category.result.totalBytes) / Double(maxSmartCategoryBytes)
    }

    private func categoryIcon(for category: SmartCategoryState) -> String {
        let title = category.result.title.lowercased()
        if title.contains("login") || title.contains("startup") {
            return "person.crop.circle.badge.clock"
        }
        if title.contains("cache") {
            return "tray.and.arrow.down"
        }
        if title.contains("privacy") {
            return "lock.shield"
        }
        if title.contains("health") {
            return "heart.text.square"
        }
        return "trash"
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
            let items = model.smartCare.categories
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

    private func statusTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum SmartCareWorkspaceTab: Hashable {
    case overview
    case categories
    case exclusions
}
