import SwiftUI
import AppKit

struct UninstallerView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var iconCache = AppIconCache()
    @State private var selectedAppPath: String?
    @State private var appSearchQuery = ""
    @State private var showUninstallPreview = false

    private var selectedApp: InstalledApp? {
        guard let selectedAppPath else { return nil }
        return model.installedApps.first { $0.appURL.path == selectedAppPath }
    }

    private var filteredApps: [InstalledApp] {
        let query = appSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.installedApps }
        let lower = query.lowercased()
        return model.installedApps.filter {
            $0.name.lowercased().contains(lower)
            || $0.bundleID.lowercased().contains(lower)
            || $0.appURL.path.lowercased().contains(lower)
        }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter applications", text: $appSearchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                List(filteredApps, selection: $selectedAppPath) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: iconCache.icon(for: app.appURL.path))
                            .resizable()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 0.6)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(app.appURL.path)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedAppPath = app.appURL.path }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
            .padding(10)
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.08, padding: 0)
            .overlay {
                if model.isUninstallerLoading {
                    ProgressView("Loading apps...")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                if let selectedApp {
                    HStack {
                        Image(nsImage: iconCache.icon(for: selectedApp.appURL.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 0.6)
                            )
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
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 12)

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
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 0)

                    if let report = model.uninstallReport {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Validation report")
                                .font(.headline)
                            Text("Removed \(report.removedCount) · Skipped \(report.skippedCount) · Failed \(report.failedCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            uninstallReportSections(report)
                        }
                        .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 12)
                    }
                    if !model.uninstallSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rollback sessions")
                                .font(.headline)
                            List(model.uninstallSessions.prefix(10)) { session in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(session.appName)
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text(session.createdAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Restore All") {
                                            _ = model.restoreFromUninstallSession(session)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    ForEach(session.rollbackItems.prefix(8)) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer()
                                            Button("Restore") {
                                                _ = model.restoreFromUninstallSession(session, item: item)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(minHeight: 170)
                        }
                        .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 12)
                    }
                } else {
                    ContentUnavailableView("Uninstaller", systemImage: "trash", description: Text("Select app to inspect remnants."))
                }
            }
            .padding(12)
            .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
        .onAppear {
            if model.installedApps.isEmpty {
                model.loadInstalledApps()
            }
            if selectedAppPath == nil {
                selectedAppPath = model.installedApps.first?.appURL.path
            }
        }
        .onChange(of: selectedAppPath) {
            guard let selectedApp else { return }
            model.loadRemnants(for: selectedApp)
        }
        .onChange(of: model.installedApps) {
            guard selectedAppPath == nil else { return }
            selectedAppPath = model.installedApps.first?.appURL.path
        }
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

@MainActor
private final class AppIconCache: ObservableObject {
    private var cache: [String: NSImage] = [:]

    func icon(for path: String) -> NSImage {
        if let image = cache[path] {
            return image
        }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 64, height: 64)
        cache[path] = image
        return image
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
