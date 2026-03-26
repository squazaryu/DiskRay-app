import SwiftUI

struct UninstallerView: View {
    @ObservedObject var model: RootViewModel
    @State private var selectedApp: InstalledApp?
    @State private var showUninstallPreview = false

    var body: some View {
        NavigationSplitView {
            List(model.installedApps, selection: $selectedApp) { app in
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if model.isUninstallerLoading {
                    ProgressView("Loading apps...")
                }
            }
            .onAppear {
                if model.installedApps.isEmpty {
                    model.loadInstalledApps()
                }
            }
            .onChange(of: selectedApp?.id) {
                guard let selectedApp else { return }
                model.loadRemnants(for: selectedApp)
            }
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                if let selectedApp {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(selectedApp.name)
                                .font(.title3.bold())
                            Text(selectedApp.appURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Uninstall", role: .destructive) {
                            showUninstallPreview = true
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Text("Detected remnants: \(model.uninstallerRemnants.count)")
                        .font(.subheadline)

                    List(model.uninstallerRemnants) { remnant in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(remnant.name)
                                Text(remnant.url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: remnant.sizeInBytes, countStyle: .file))
                                .font(.caption)
                        }
                    }

                    if let report = model.uninstallReport {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Validation report")
                                .font(.headline)
                            Text("Removed \(report.removedCount) · Skipped \(report.skippedCount) · Failed \(report.failedCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            List(report.results) { row in
                                HStack(alignment: .top) {
                                    Text(statusTitle(row.status))
                                        .font(.caption.bold())
                                        .foregroundStyle(statusColor(row.status))
                                        .frame(width: 74, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.url.path)
                                            .font(.caption)
                                            .lineLimit(1)
                                        if let details = row.details {
                                            Text(details)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(minHeight: 160)
                        }
                    }
                } else {
                    ContentUnavailableView("Uninstaller", systemImage: "trash", description: Text("Select app to inspect remnants."))
                }
            }
            .padding()
            .sheet(isPresented: $showUninstallPreview) {
                if let selectedApp {
                    UninstallPreviewSheet(
                        app: selectedApp,
                        previewItems: model.uninstallPreview(for: selectedApp),
                        onConfirm: {
                            model.uninstall(app: selectedApp)
                            showUninstallPreview = false
                        }
                    )
                }
            }
        }
    }

    private func statusTitle(_ status: UninstallActionStatus) -> String {
        switch status {
        case .removed: return "Removed"
        case .skippedProtected: return "Skipped"
        case .missing: return "Missing"
        case .failed: return "Failed"
        }
    }

    private func statusColor(_ status: UninstallActionStatus) -> Color {
        switch status {
        case .removed: return .green
        case .skippedProtected, .missing: return .orange
        case .failed: return .red
        }
    }
}

private struct UninstallPreviewSheet: View {
    let app: InstalledApp
    let previewItems: [UninstallPreviewItem]
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uninstall Preview")
                .font(.title3.bold())
            Text(app.name)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Will remove \(previewItems.count) item(s)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(previewItems) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text(riskTitle(item.risk))
                        .font(.caption2.bold())
                        .foregroundStyle(riskColor(item.risk))
                        .frame(width: 58, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.url.lastPathComponent)
                            .font(.subheadline)
                        Text(item.url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(item.reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if item.sizeInBytes > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: item.sizeInBytes, countStyle: .file))
                            .font(.caption)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Move to Trash", role: .destructive) { onConfirm() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 460)
    }

    private func riskTitle(_ risk: UninstallRiskLevel) -> String {
        switch risk {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    private func riskColor(_ risk: UninstallRiskLevel) -> Color {
        switch risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}
