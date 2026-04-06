import SwiftUI

private enum PrivacyCleanMode {
    case selected
    case safeLowRisk
    case recommended
}

struct PrivacyView: View {
    @ObservedObject var model: RootViewModel
    @State private var expanded = Set<String>()
    @State private var showConfirm = false
    @State private var pendingCleanMode: PrivacyCleanMode = .selected

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if model.isPrivacyScanRunning {
                ProgressView("Scanning privacy artifacts...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            if let cleanReport = model.privacyCleanReport {
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
                .padding(.horizontal, 4)
            }

            if let delta = model.privacyQuickActionDelta {
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
                .padding(.horizontal, 4)
            }

            Group {
                if model.privacyCategories.isEmpty, !model.isPrivacyScanRunning {
                    ContentUnavailableView(
                        "No Privacy Scan Results",
                        systemImage: "lock.shield",
                        description: Text("Run scan to review browser and local privacy traces.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    categoriesList
                }
            }
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.05, padding: 0)
        }
        .padding(12)
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

    private var header: some View {
        ModuleHeaderCard(
            title: "Privacy",
            subtitle: "Review local traces and clean selected categories with explicit control."
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "Categories \(model.privacyCategories.count)", tint: .blue)
                    GlassPillBadge(title: "Selected \(selectedCount)", tint: .green)
                    GlassPillBadge(
                        title: "Estimated \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))",
                        tint: .orange
                    )
                }

                HStack(spacing: 8) {
                    Button("Scan Privacy Traces") {
                        model.runPrivacyScan()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.isPrivacyScanRunning)

                    Button("Select Low Risk") {
                        model.selectRecommendedPrivacyCategories(includeMediumRisk: false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.privacyCategories.isEmpty)

                    Button("Select Recommended") {
                        model.selectRecommendedPrivacyCategories(includeMediumRisk: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.privacyCategories.isEmpty)

                    Button("Clear") {
                        model.clearPrivacySelection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedCount == 0)
                }

                HStack(spacing: 8) {
                    Button("Clean Selected") {
                        pendingCleanMode = .selected
                        showConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedCount == 0)

                    Button("Quick Clean Safe") {
                        pendingCleanMode = .safeLowRisk
                        showConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.privacyCategories.isEmpty)

                    Button("Quick Clean Recommended") {
                        pendingCleanMode = .recommended
                        showConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.privacyCategories.isEmpty)
                }
            }
        }
    }

    private var categoriesList: some View {
        List {
            Section("Transparency Report") {
                Text("Selected categories: \(selectedCount)")
                Text("Items to clean: \(selectedArtifactsCount)")
                Text("Estimated reclaim: \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))")
            }

            ForEach(model.privacyCategories) { row in
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
                set: { _ in model.togglePrivacyCategory(row.id) }
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
            model.cleanSelectedPrivacyCategories()
        case .safeLowRisk:
            model.cleanRecommendedPrivacyCategories(includeMediumRisk: false)
        case .recommended:
            model.cleanRecommendedPrivacyCategories(includeMediumRisk: true)
        }
    }

    private var selectedCount: Int {
        model.privacyCategories.filter(\.isSelected).count
    }

    private var selectedArtifactsCount: Int {
        model.privacyCategories.filter(\.isSelected).reduce(0) { $0 + $1.category.artifacts.count }
    }

    private var selectedBytes: Int64 {
        model.privacyCategories.filter(\.isSelected).reduce(0) { $0 + $1.category.totalBytes }
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
}
