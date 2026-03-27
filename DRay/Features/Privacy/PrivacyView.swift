import SwiftUI

struct PrivacyView: View {
    @ObservedObject var model: RootViewModel
    @State private var expanded = Set<String>()
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy")
                        .font(.title2.bold())
                    Text("Review local traces and clean only explicitly selected categories.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Scan Privacy Traces") {
                    model.runPrivacyScan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isPrivacyScanRunning)

                Button("Clean Selected") {
                    showConfirm = true
                }
                .buttonStyle(.bordered)
                .disabled(selectedCount == 0)
            }

            if model.isPrivacyScanRunning {
                ProgressView("Scanning privacy artifacts...")
            }

            if let cleanReport = model.privacyCleanReport {
                Text("Last cleanup: moved \(cleanReport.moved), failed \(cleanReport.failed), skipped \(cleanReport.skippedProtected), reclaimed \(ByteCountFormatter.string(fromByteCount: cleanReport.cleanedBytes, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.privacyCategories.isEmpty, !model.isPrivacyScanRunning {
                ContentUnavailableView(
                    "No Privacy Scan Results",
                    systemImage: "lock.shield",
                    description: Text("Run scan to review browser and local privacy traces.")
                )
            } else {
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
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .confirmationDialog(
            "Clean selected privacy categories?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                model.cleanSelectedPrivacyCategories()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected artifacts will be moved to Trash. You can restore them from Trash if needed.")
        }
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
