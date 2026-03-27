import SwiftUI
import AppKit

struct UninstallerView: View {
    @ObservedObject var model: RootViewModel
    @State private var selectedAppPath: String?
    @State private var showUninstallPreview = false

    private var selectedApp: InstalledApp? {
        guard let selectedAppPath else { return nil }
        return model.installedApps.first { $0.appURL.path == selectedAppPath }
    }

    var body: some View {
        NavigationSplitView {
            List(model.installedApps, selection: $selectedAppPath) { app in
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(app.appURL.path)
                .contentShape(Rectangle())
                .onTapGesture { selectedAppPath = app.appURL.path }
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
            .onChange(of: selectedAppPath) {
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
                            uninstallReportSections(report)
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
                        onConfirm: { selectedItems in
                            model.uninstall(app: selectedApp, selectedItems: selectedItems)
                            showUninstallPreview = false
                        }
                    )
                }
            }
        }
    }

    private func uninstallReportSections(_ report: UninstallValidationReport) -> some View {
        List {
            reportSection(title: "Removed", status: .removed, rows: report.results)
            reportSection(title: "Skipped", status: .skippedProtected, rows: report.results)
            reportSection(title: "Missing", status: .missing, rows: report.results)
            reportSection(title: "Failed", status: .failed, rows: report.results)
        }
        .frame(minHeight: 200)
    }

    private func reportSection(title: String, status: UninstallActionStatus, rows: [UninstallActionResult]) -> some View {
        let sectionRows = rows.filter { $0.status == status }
        return Section {
            if sectionRows.isEmpty {
                Text("No items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sectionRows) { row in
                    HStack(alignment: .top, spacing: 8) {
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
                        Spacer()
                        Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([row.url]) }
                            .buttonStyle(.borderless)
                        Button("Copy Path") { copyToPasteboard(row.url.path) }
                            .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            Text("\(title) (\(sectionRows.count))")
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
    let onConfirm: ([UninstallPreviewItem]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPaths = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uninstall Preview")
                .font(.title3.bold())
            Text(app.name)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Selected \(selectedItems.count) of \(previewItems.count) item(s)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Select All") { selectedPaths = Set(previewItems.map(\.url.path)) }
                Button("Select Safe") {
                    selectedPaths = Set(previewItems.filter { $0.risk != .high }.map(\.url.path))
                    if previewItems.contains(where: { $0.type == .appBundle }) {
                        selectedPaths.insert(app.appURL.path)
                    }
                }
                Button("Clear") { selectedPaths.removeAll() }
                Spacer()
            }

            List(previewItems) { item in
                HStack(alignment: .top, spacing: 10) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { selectedPaths.contains(item.url.path) },
                            set: { isOn in
                                if isOn { selectedPaths.insert(item.url.path) }
                                else { selectedPaths.remove(item.url.path) }
                            }
                        )
                    )
                    .labelsHidden()

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
                Button("Move to Trash", role: .destructive) { onConfirm(selectedItems) }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedItems.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 460)
        .onAppear {
            selectedPaths = Set(previewItems.map(\.url.path))
        }
    }

    private var selectedItems: [UninstallPreviewItem] {
        previewItems.filter { selectedPaths.contains($0.url.path) }
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
