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

    private var selectedArtifacts: [AppRemnant] {
        let selected = selectedArtifactPaths
        return model.repairArtifacts.filter { selected.contains($0.url.path) }
    }

    private var reclaimedSizeText: String {
        let total = selectedArtifacts.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var strategyPreviewArtifacts: [AppRemnant] {
        model.recommendedRepairArtifacts(for: repairStrategy)
    }

    private var strategyPreviewSizeText: String {
        let total = strategyPreviewArtifacts.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var strategyRiskCounts: (low: Int, medium: Int, high: Int) {
        strategyPreviewArtifacts.reduce(into: (low: 0, medium: 0, high: 0)) { partial, artifact in
            switch model.repairRisk(for: artifact) {
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
        VStack(spacing: 10) {
            header

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
                    }
                    .padding(.vertical, 4)
                    .tag(app.appURL.path)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedAppPath = app.appURL.path }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                selectedAppPath == app.appURL.path
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                            )
                    )
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
            .padding(10)
            .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.08, padding: 0)

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
                            model.loadRepairArtifacts(for: selectedApp)
                        }
                        .buttonStyle(.bordered)
                        Button("Repair") {
                            model.runAppRepair(
                                app: selectedApp,
                                artifacts: selectedArtifacts.isEmpty ? model.repairArtifacts : selectedArtifacts,
                                relaunchAfterRepair: relaunchAfterRepair
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.repairArtifacts.isEmpty || model.isRepairLoading)
                    }
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 12)

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
                        .frame(width: 140)
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
                    .glassSurface(cornerRadius: 12, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 10)

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
                    .glassSurface(cornerRadius: 12, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 10)

                    List(model.repairArtifacts, selection: $selectedArtifactPaths) { artifact in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(artifact.name)
                                        .font(.subheadline.weight(.semibold))
                                    let risk = model.repairRisk(for: artifact)
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
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: artifact.sizeInBytes, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(artifact.url.path)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 0)
                    .overlay {
                        if model.isRepairLoading {
                            ProgressView("Repair scan in progress...")
                        }
                    }

                    if let report = model.repairReport {
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
                        .glassSurface(cornerRadius: 12, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 10)
                    }

                    if !model.repairSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repair rollback sessions")
                                .font(.headline)
                            List(model.repairSessions.prefix(10)) { session in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(session.appName)
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text(session.createdAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Restore All") {
                                            let restored = model.restoreFromRepairSession(session)
                                            if restored > 0 {
                                                model.loadRepairArtifacts(for: selectedApp)
                                            }
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
                                                let restored = model.restoreFromRepairSession(session, item: item)
                                                if restored > 0 {
                                                    model.loadRepairArtifacts(for: selectedApp)
                                                }
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(minHeight: 170)
                        }
                        .glassSurface(cornerRadius: 12, strokeOpacity: 0.1, shadowOpacity: 0.05, padding: 10)
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
        .padding(.vertical, 8)
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
            selectedArtifactPaths = []
            model.loadRepairArtifacts(for: selectedApp)
        }
        .onChange(of: model.installedApps) {
            guard selectedAppPath == nil else { return }
            selectedAppPath = model.installedApps.first?.appURL.path
        }
        .onChange(of: model.repairArtifacts) {
            let available = Set(model.repairArtifacts.map { $0.url.path })
            selectedArtifactPaths = selectedArtifactPaths.intersection(available)
            if selectedArtifactPaths.isEmpty {
                selectedArtifactPaths = Set(model.recommendedRepairArtifacts(for: repairStrategy).map { $0.url.path })
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
            HStack(spacing: 8) {
                GlassPillBadge(title: "\(filteredApps.count) apps", tint: .blue)
                GlassPillBadge(title: "\(model.repairArtifacts.count) artifacts", tint: .orange)
                GlassPillBadge(title: "Selected \(selectedArtifacts.count)", tint: .green)

                Button("Rescan Apps") {
                    model.loadInstalledApps()
                }
                .buttonStyle(.bordered)
            }
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
