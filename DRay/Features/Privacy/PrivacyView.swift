import SwiftUI

private enum PrivacyCleanMode {
    case selected
    case safeLowRisk
    case recommended
}

struct PrivacyView: View {
    @StateObject private var model: PrivacyViewModel
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    @State private var expanded = Set<String>()
    @State private var showConfirm = false
    @State private var pendingCleanMode: PrivacyCleanMode = .selected
    @State private var workspaceTab: PrivacyWorkspaceTab = .overview

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: PrivacyViewModel(root: rootModel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.sectionSpacing) {
            header
            privacyToolbar
            workspaceNavigation
            statusStrip

            if model.state.isScanRunning {
                ProgressView("Scanning privacy artifacts...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            Group {
                switch workspaceTab {
                case .overview:
                    overviewWorkspace
                case .categories:
                    categoriesWorkspace
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: workspaceTab == .categories ? 0 : layoutMetrics.cardSpacing)
        }
        .padding(layoutMetrics.cardSpacing)
        .confirmationDialog(
            confirmTitle,
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                executePendingClean()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text("Overview").tag(PrivacyWorkspaceTab.overview)
                Text("Categories").tag(PrivacyWorkspaceTab.categories)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 2)
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            DRayCompactInfoTile(title: "Categories", value: "\(model.state.categories.count)", subtitle: "privacy groups", icon: "lock.shield", tint: .blue)
            DRayCompactInfoTile(title: "Selected", value: "\(selectedCount)", subtitle: "cleanup scope", icon: "checkmark.circle", tint: .green, progress: model.state.categories.isEmpty ? 0 : Double(selectedCount) / Double(model.state.categories.count))
            DRayCompactInfoTile(
                title: "Items",
                value: "\(selectedArtifactsCount)",
                subtitle: "artifacts",
                icon: "doc.text",
                tint: selectedArtifactsCount > 0 ? .orange : .secondary,
                progress: min(1, Double(selectedArtifactsCount) / 200)
            )
            DRayCompactInfoTile(
                title: "Estimated",
                value: ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file),
                subtitle: "footprint",
                icon: "externaldrive.badge.minus",
                tint: .purple,
                progress: min(1, Double(selectedBytes) / Double(1024 * 1024 * 1024))
            )
        }
    }

    private var overviewWorkspace: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            if let cleanReport = model.state.cleanReport {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "Moved \(cleanReport.moved)", tint: .green)
                    GlassPillBadge(title: "Failed \(cleanReport.failed)", tint: .red)
                    GlassPillBadge(title: "Skipped \(cleanReport.skippedProtected)", tint: .orange)
                    GlassPillBadge(
                        title: "Reclaimed \(ByteCountFormatter.string(fromByteCount: cleanReport.cleanedBytes, countStyle: .file))",
                        tint: .blue
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let delta = model.state.quickActionDelta {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "Action \(delta.actionTitle)", tint: .blue)
                    GlassPillBadge(title: "Items \(delta.beforeItems) -> \(delta.afterItems)", tint: .green)
                    GlassPillBadge(
                        title: "Size \(ByteCountFormatter.string(fromByteCount: delta.beforeBytes, countStyle: .file)) -> \(ByteCountFormatter.string(fromByteCount: delta.afterBytes, countStyle: .file))",
                        tint: .orange
                    )
                    Spacer()
                    Text("Updated \(delta.createdAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.state.categories.isEmpty, !model.state.isScanRunning {
                ContentUnavailableView(
                    "No Privacy Scan Results",
                    systemImage: "lock.shield",
                    description: Text("Run scan to review browser and local privacy traces.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            DRayIconBadge(icon: "lock.shield", tint: .purple, size: 30)
                            Text("Privacy Exposure")
                                .font(.headline)
                            Spacer()
                        }
                        ForEach(Array(model.state.categories.prefix(5).enumerated()), id: \.element.id) { index, row in
                            DRayRankedBarRow(
                                rank: index + 1,
                                title: row.category.title,
                                subtitle: "\(row.category.artifacts.count) items · \(riskLabel(row.category.risk))",
                                value: ByteCountFormatter.string(fromByteCount: row.category.totalBytes, countStyle: .file),
                                progress: privacyCategoryProgress(row),
                                tint: riskColor(row.category.risk),
                                icon: "eye.slash"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .padding(layoutMetrics.cardSpacing)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            DRayIconBadge(icon: "sparkles", tint: .green, size: 30)
                            Text("Recommended Flow")
                                .font(.headline)
                            Spacer()
                        }
                        DRayActionRow(
                            title: "Select Recommended",
                            subtitle: "Low and medium risk traces only.",
                            icon: "checkmark.shield",
                            tint: .green,
                            actionTitle: "Select"
                        ) { model.selectRecommended(includeMediumRisk: true) }
                        DRayActionRow(
                            title: "Review Categories",
                            subtitle: "Inspect before destructive cleanup.",
                            icon: "list.bullet.rectangle",
                            tint: .purple,
                            actionTitle: "Open"
                        ) { workspaceTab = .categories }
                    }
                    .frame(width: 340, alignment: .topLeading)
                    .frame(minHeight: 190, alignment: .topLeading)
                    .padding(layoutMetrics.cardSpacing)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
                }
            }
        }
    }

    @ViewBuilder
    private var categoriesWorkspace: some View {
        if model.state.categories.isEmpty, !model.state.isScanRunning {
            ContentUnavailableView(
                "No Privacy Scan Results",
                systemImage: "lock.shield",
                description: Text("Run scan to review browser and local privacy traces.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                categoriesActionStrip
                categoriesList
            }
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: "Privacy",
            subtitle: "Review local traces and clean selected categories with explicit control."
        ) {
            EmptyView()
        }
    }

    private var privacyToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Scan Privacy Traces") {
                    model.runScan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.state.isScanRunning)

                Button("Select Low Risk") {
                    model.selectRecommended(includeMediumRisk: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.state.categories.isEmpty)

                Button("Select Recommended") {
                    model.selectRecommended(includeMediumRisk: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.state.categories.isEmpty)

                Button("Clear") {
                    model.clearSelection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, layoutMetrics.cardSpacing)
            .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        }
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var categoriesActionStrip: some View {
        HStack(spacing: 8) {
            GlassPillBadge(title: "Selected \(selectedCount)", tint: .green)
            GlassPillBadge(
                title: "Estimated \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))",
                tint: .orange
            )
            Spacer(minLength: 8)

            Button("Clean Selected") {
                pendingCleanMode = .selected
                showConfirm = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedCount == 0)

            Button("Quick Clean Safe") {
                pendingCleanMode = .safeLowRisk
                showConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.state.categories.isEmpty)

            Button("Quick Clean Recommended") {
                pendingCleanMode = .recommended
                showConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.state.categories.isEmpty)
        }
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.top, 8)
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
        .padding(layoutMetrics.cardSpacing)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var categoriesList: some View {
        List {
            Section("Transparency Report") {
                Text("Selected categories: \(selectedCount)")
                Text("Items to clean: \(selectedArtifactsCount)")
                Text("Estimated reclaim: \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))")
            }

            ForEach(model.state.categories) { row in
                Section {
                    categoryRow(row)
                    if expanded.contains(row.id) {
                        ForEach(row.category.artifacts.prefix(50)) { item in
                            HStack {
                                Text(item.url.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: item.sizeInBytes, countStyle: .file))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func categoryRow(_ row: PrivacyCategoryState) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(
                get: { row.isSelected },
                set: { _ in model.toggleCategory(row.id) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(row.category.title)
                    .font(.headline)
                Text(row.category.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(row.category.artifacts.count) items · \(ByteCountFormatter.string(fromByteCount: row.category.totalBytes, countStyle: .file))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(riskLabel(row.category.risk))
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColor(row.category.risk).opacity(0.15), in: Capsule())
            Button(expanded.contains(row.id) ? "Hide" : "Preview") {
                if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private var confirmTitle: String {
        switch pendingCleanMode {
        case .selected:
            return "Clean selected privacy categories?"
        case .safeLowRisk:
            return "Quick clean low-risk privacy traces?"
        case .recommended:
            return "Quick clean recommended privacy traces?"
        }
    }

    private var confirmMessage: String {
        switch pendingCleanMode {
        case .selected:
            return "Selected artifacts will be moved to Trash. You can restore them from Trash if needed."
        case .safeLowRisk:
            return "Only low-risk categories will be selected and moved to Trash."
        case .recommended:
            return "Low and medium risk categories will be selected and moved to Trash. High-risk categories stay untouched."
        }
    }

    private func executePendingClean() {
        switch pendingCleanMode {
        case .selected:
            model.cleanSelected()
        case .safeLowRisk:
            model.cleanRecommended(includeMediumRisk: false)
        case .recommended:
            model.cleanRecommended(includeMediumRisk: true)
        }
    }

    private var selectedCount: Int {
        model.state.categories.filter(\.isSelected).count
    }

    private var selectedArtifactsCount: Int {
        model.state.categories.filter(\.isSelected).reduce(0) { $0 + $1.category.artifacts.count }
    }

    private var selectedBytes: Int64 {
        model.state.categories.filter(\.isSelected).reduce(0) { $0 + $1.category.totalBytes }
    }

    private func privacyCategoryProgress(_ row: PrivacyCategoryState) -> Double {
        let maxBytes = max(model.state.categories.map { $0.category.totalBytes }.max() ?? 0, 1)
        return min(1, Double(row.category.totalBytes) / Double(maxBytes))
    }

    private func riskLabel(_ risk: PrivacyRisk) -> String {
        switch risk {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }

    private func riskColor(_ risk: PrivacyRisk) -> Color {
        switch risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
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
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum PrivacyWorkspaceTab: Hashable {
    case overview
    case categories
}
