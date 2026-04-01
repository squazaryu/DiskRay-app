import SwiftUI
import AppKit

struct UninstallerView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var iconCache = AppIconCache()
    @State private var selectedAppPath: String?
    @State private var appSearchQuery = ""
    @State private var showUninstallPreview = false

    private var remnantTotalSizeText: String {
        let total = model.uninstallerRemnants.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

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
        VStack(alignment: .leading, spacing: 10) {
            header

            HStack(alignment: .top, spacing: 12) {
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

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredApps) { app in
                                appSidebarRow(app)
                            }
                        }
                        .padding(6)
                    }
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                .padding(10)
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.04, shadowOpacity: 0.04, padding: 0)
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
                        .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)

                        HStack(spacing: 8) {
                            GlassPillBadge(title: "Detected remnants: \(model.uninstallerRemnants.count)", tint: .orange)
                            GlassPillBadge(title: "Size \(remnantTotalSizeText)", tint: .blue)
                            if let report = model.uninstallReport {
                                GlassPillBadge(title: "Removed \(report.removedCount)", tint: .green)
                                GlassPillBadge(title: "Failed \(report.failedCount)", tint: .red)
                            }
                        }

                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(model.uninstallerRemnants) { remnant in
                                    remnantRow(remnant)
                                }
                            }
                            .padding(8)
                        }
                        .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)
                        .overlay {
                            if model.uninstallerRemnants.isEmpty && !model.isUninstallerLoading {
                                ContentUnavailableView(
                                    "No remnants found",
                                    systemImage: "checkmark.seal",
                                    description: Text("Selected app has no removable leftovers in known locations.")
                                )
                            }
                        }

                        if let report = model.uninstallReport {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Validation report")
                                    .font(.headline)
                                Text("Removed \(report.removedCount) · Skipped \(report.skippedCount) · Failed \(report.failedCount)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                uninstallReportSections(report)
                            }
                            .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)
                        }

                        if model.isUninstallVerifyRunning {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Post-uninstall verify pass in progress...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)
                        } else if let verify = model.uninstallVerifyReport {
                            uninstallVerifyPanel(verify, app: selectedApp)
                        }

                        if !model.uninstallSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Rollback sessions")
                                    .font(.headline)
                                ScrollView {
                                    LazyVStack(spacing: 8) {
                                        ForEach(Array(model.uninstallSessions.prefix(10))) { session in
                                            rollbackSessionCard(session)
                                        }
                                    }
                                    .padding(8)
                                }
                                .frame(minHeight: 170)
                            }
                            .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)
                        }
                    } else {
                        ContentUnavailableView("Uninstaller", systemImage: "trash", description: Text("Select app to inspect remnants."))
                    }
                }
                .padding(12)
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
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

    private var header: some View {
        ModuleHeaderCard(
            title: "Uninstaller",
            subtitle: "Inspect app remnants and remove applications with rollback support. Apps: \(filteredApps.count)."
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "\(filteredApps.count) apps", tint: .blue)
                    GlassPillBadge(title: "\(model.uninstallerRemnants.count) remnants", tint: .orange)

                    Button("Rescan Apps") {
                        model.loadInstalledApps()
                    }
                    .buttonStyle(.bordered)

                    Button("Open App Repair") {
                        model.openSection(.repair)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func appSidebarRow(_ app: InstalledApp) -> some View {
        let selected = selectedAppPath == app.appURL.path
        return Button {
            selectedAppPath = app.appURL.path
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: iconCache.icon(for: app.appURL.path))
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func remnantRow(_ remnant: AppRemnant) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(remnant.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(remnant.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(ByteCountFormatter.string(fromByteCount: remnant.sizeInBytes, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rollbackSessionCard(_ session: UninstallSession) -> some View {
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
                .buttonStyle(.bordered)
                .controlSize(.small)
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
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func uninstallReportSections(_ report: UninstallValidationReport) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                reportSectionCard(title: "Removed", status: .removed, rows: report.results)
                reportSectionCard(title: "Skipped", status: .skippedProtected, rows: report.results)
                reportSectionCard(title: "Missing", status: .missing, rows: report.results)
                reportSectionCard(title: "Failed", status: .failed, rows: report.results)
            }
            .padding(8)
        }
        .frame(minHeight: 200)
    }

    private func uninstallVerifyPanel(_ verify: UninstallVerifyReport, app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Post-uninstall verify")
                    .font(.headline)
                Spacer()
                Button("Re-run Verify") {
                    model.runUninstallVerifyPass(for: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Attempted \(verify.attemptedItems) · Removed \(verify.removedItems) · Remaining \(verify.remainingCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if verify.remaining.isEmpty {
                Label("No leftovers detected after verification.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(verify.remaining) { issue in
                            uninstallVerifyIssueRow(issue)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 160, maxHeight: 260)
            }
        }
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)
    }

    private func uninstallVerifyIssueRow(_ issue: UninstallVerifyIssue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(riskTitle(issue.risk))
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(riskColor(issue.risk).opacity(0.14), in: Capsule())
                .foregroundStyle(riskColor(issue.risk))

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(issue.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(issue.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(ByteCountFormatter.string(fromByteCount: issue.sizeInBytes, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([issue.url])
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func reportSectionCard(title: String, status: UninstallActionStatus, rows: [UninstallActionResult]) -> some View {
        let sectionRows = rows.filter { $0.status == status }
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(sectionRows.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
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
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
