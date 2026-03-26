import SwiftUI

struct UninstallerView: View {
    @ObservedObject var model: RootViewModel
    @State private var selectedApp: InstalledApp?
    @State private var showUninstallConfirm = false

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
                            showUninstallConfirm = true
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
            .confirmationDialog(
                "Uninstall app and move detected remnants to Trash?",
                isPresented: $showUninstallConfirm,
                titleVisibility: .visible
            ) {
                Button("Uninstall", role: .destructive) {
                    guard let selectedApp else { return }
                    model.uninstall(app: selectedApp)
                }
                Button("Cancel", role: .cancel) {}
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
