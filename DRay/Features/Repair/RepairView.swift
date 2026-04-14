import SwiftUI
import AppKit

struct RepairView: View {
    @ObservedObject var model: RootViewModel
    @StateObject private var iconCache = RepairAppIconCache()
    @State private var selectedAppPath: String?
    @State private var appSearchQuery = ""
    @State private var selectedArtifactPaths = Set<String>()
    @State private var relaunchAfterRepair = true
    @State private var repairStrategy: AppRepairStrategy = .safeReset
    @State private var showDeepResetConfirm = false

    private var installedApps: [InstalledApp] {
        model.uninstaller.state.installedApps
    }

    private var repairState: RepairFeatureState {
        model.repair.state
    }

    private var repairArtifacts: [AppRemnant] {
        repairState.artifacts
    }

    private var isRepairLoading: Bool {
        repairState.isLoading
    }

    private var repairReport: UninstallValidationReport? {
        repairState.report
    }

    private var repairSessions: [UninstallSession] {
        repairState.sessions
    }

    private var selectedApp: InstalledApp? {
        guard let selectedAppPath else { return nil }
        return installedApps.first { $0.appURL.path == selectedAppPath }
    }

    private var filteredApps: [InstalledApp] {
        let query = appSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return installedApps }
        let lower = query.lowercased()
        return installedApps.filter {
            $0.name.lowercased().contains(lower)
            || $0.bundleID.lowercased().contains(lower)
            || $0.appURL.path.lowercased().contains(lower)
        }
    }

    private var selectedArtifacts: [AppRemnant] {
        let selected = selectedArtifactPaths
        return repairArtifacts.filter { selected.contains($0.url.path) }
    }

    private var reclaimedSizeText: String {
        let total = selectedArtifacts.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var strategyPreviewArtifacts: [AppRemnant] {
        model.repair.recommendedArtifacts(for: repairStrategy)
    }

    private var strategyPreviewSizeText: String {
        let total = strategyPreviewArtifacts.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var strategyRiskCounts: (low: Int, medium: Int, high: Int) {
        strategyPreviewArtifacts.reduce(into: (low: 0, medium: 0, high: 0)) { partial, artifact in
            switch model.repair.repairRisk(for: artifact) {
            case .low:
                partial.low += 1
            case .medium:
                partial.medium += 1
            case .high:
                partial.high += 1
            }
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
                                repairSidebarRow(app)
                            }
                        }
                        .padding(6)
                    }
                }
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 330)
                .padding(10)
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.04, shadowOpacity: 0.04, padding: 0)

                VStack(alignment: .leading, spacing: 12) {
                    if let selectedApp {
                        HStack {
                            Image(nsImage: iconCache.icon(for: selectedApp.appURL.path))
                                .resizable()
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Repair")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(selectedApp.name)
                                    .font(.title3.bold())
                                Text(selectedApp.appURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Rescan Artifacts") {
                                model.repair.loadArtifacts(for: selectedApp)
                            }
                            .buttonStyle(.bordered)
                            Button("Repair") {
                                model.repair.runRepair(
                                    app: selectedApp,
                                    artifacts: selectedArtifacts.isEmpty ? repairArtifacts : selectedArtifacts
                                ) { _ in
                                    model.repair.loadArtifacts(for: selectedApp)
                                    if relaunchAfterRepair {
                                        relaunch(selectedApp)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(repairArtifacts.isEmpty || isRepairLoading)
                        }
                        .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 12)

                        HStack {
                            Toggle("Relaunch app after repair", isOn: $relaunchAfterRepair)
                                .toggleStyle(.switch)
                            Spacer()
                            Picker("Strategy", selection: $repairStrategy) {
                                ForEach(AppRepairStrategy.allCases) { strategy in
                                    Text(strategy.title).tag(strategy)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 246)
                            .fixedSize(horizontal: true, vertical: false)
                            Button("Apply Strategy") {
                                applySelectedStrategy()
                            }
                            .buttonStyle(.bordered)
                            Text("Selected: \(selectedArtifacts.count)")
                                .font(.subheadline.weight(.semibold))
                            Text("Reclaimable: \(reclaimedSizeText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .glassSurface(cornerRadius: 12, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 10)

                        HStack(spacing: 8) {
                            Text(repairStrategy.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Spacer()
                            Text("Preview \(strategyPreviewArtifacts.count) · \(strategyPreviewSizeText)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            riskBadge("Low \(strategyRiskCounts.low)", color: .green)
                            riskBadge("Med \(strategyRiskCounts.medium)", color: .orange)
                            riskBadge("High \(strategyRiskCounts.high)", color: .red)
                        }
                        .glassSurface(cornerRadius: 12, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 10)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(repairArtifacts) { artifact in
                                repairArtifactRow(artifact)
                            }
                        }
                        .padding(8)
                    }
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 0)
                    .overlay {
                        if isRepairLoading {
                            ProgressView("Repair scan in progress...")
                        }
                    }

                    if let report = repairReport {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Repair report")
                                .font(.headline)
                            Text("Removed \(report.removedCount) · Skipped \(report.skippedCount) · Failed \(report.failedCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(repairStrategy.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .glassSurface(cornerRadius: 12, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 10)
                    }

                    if !repairSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repair rollback sessions")
                                .font(.headline)
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(repairSessions.prefix(10))) { session in
                                        repairRollbackSessionCard(session)
                                    }
                                }
                                .padding(8)
                            }
                            .frame(minHeight: 170)
                        }
                        .glassSurface(cornerRadius: 12, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: 10)
                    }
                } else {
                    ContentUnavailableView(
                        "App Repair",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Select application to scan and clean corrupted leftovers without reinstalling.")
                    )
                }
                }
                .padding(12)
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .onAppear {
            if installedApps.isEmpty {
                model.uninstaller.loadInstalledApps()
            }
            if selectedAppPath == nil {
                selectedAppPath = installedApps.first?.appURL.path
            }
        }
        .onChange(of: selectedAppPath) {
            guard let selectedApp else { return }
            selectedArtifactPaths = []
            model.repair.loadArtifacts(for: selectedApp)
        }
        .onChange(of: installedApps) {
            guard selectedAppPath == nil else { return }
            selectedAppPath = installedApps.first?.appURL.path
        }
        .onChange(of: repairArtifacts) {
            let available = Set(repairArtifacts.map { $0.url.path })
            selectedArtifactPaths = selectedArtifactPaths.intersection(available)
            if selectedArtifactPaths.isEmpty {
                selectedArtifactPaths = Set(model.repair.recommendedArtifacts(for: repairStrategy).map { $0.url.path })
            }
        }
        .confirmationDialog(
            "Apply Deep Reset Strategy?",
            isPresented: $showDeepResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Apply Deep Reset", role: .destructive) {
                selectedArtifactPaths = Set(strategyPreviewArtifacts.map { $0.url.path })
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deep Reset selects \(strategyPreviewArtifacts.count) artifact(s) (\(strategyPreviewSizeText)), including medium/high risk entries.")
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: "App Repair",
            subtitle: "Reset problematic app data safely without reinstalling."
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GlassPillBadge(title: "\(filteredApps.count) apps", tint: .blue)
                    GlassPillBadge(title: "\(repairArtifacts.count) artifacts", tint: .orange)
                    GlassPillBadge(title: "Selected \(selectedArtifacts.count)", tint: .green)

                    Button("Rescan Apps") {
                        model.uninstaller.loadInstalledApps()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func repairSidebarRow(_ app: InstalledApp) -> some View {
        let selected = selectedAppPath == app.appURL.path
        return Button {
            selectedAppPath = app.appURL.path
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: iconCache.icon(for: app.appURL.path))
                    .resizable()
                    .frame(width: 20, height: 20)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func repairArtifactRow(_ artifact: AppRemnant) -> some View {
        let isSelected = selectedArtifactPaths.contains(artifact.url.path)
        let risk = model.repair.repairRisk(for: artifact)
        return Button {
            toggleArtifactSelection(artifact.url.path)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(artifact.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(riskLabel(risk))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(riskColor(risk).opacity(0.15), in: Capsule())
                    }
                    Text(artifact.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(ByteCountFormatter.string(fromByteCount: artifact.sizeInBytes, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func repairRollbackSessionCard(_ session: UninstallSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.appName)
                    .font(.subheadline.bold())
                Spacer()
                Text(session.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Restore All") {
                    let restored = model.repair.restoreFromSession(session)
                    if restored.restoredCount > 0 {
                        if let selectedApp {
                            model.repair.loadArtifacts(for: selectedApp)
                        }
                    }
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
                        let restored = model.repair.restoreFromSession(session, item: item)
                        if restored.restoredCount > 0 {
                            if let selectedApp {
                                model.repair.loadArtifacts(for: selectedApp)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toggleArtifactSelection(_ path: String) {
        if selectedArtifactPaths.contains(path) {
            selectedArtifactPaths.remove(path)
        } else {
            selectedArtifactPaths.insert(path)
        }
    }

    private func riskLabel(_ risk: UninstallRiskLevel) -> String {
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

    private func applySelectedStrategy() {
        if repairStrategy == .deepReset {
            showDeepResetConfirm = true
            return
        }
        selectedArtifactPaths = Set(strategyPreviewArtifacts.map { $0.url.path })
    }

    private func relaunch(_ app: InstalledApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
        running.forEach { $0.terminate() }
        _ = NSWorkspace.shared.open(app.appURL)
    }

    private func riskBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

@MainActor
private final class RepairAppIconCache: ObservableObject {
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
