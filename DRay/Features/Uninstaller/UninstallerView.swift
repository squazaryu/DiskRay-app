import SwiftUI
import AppKit

struct UninstallerView: View {
    @StateObject private var model: UninstallerViewModel
    @StateObject private var iconCache = AppIconCache()
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    @State private var selectedAppPath: String?
    @State private var appSearchQuery = ""
    @State private var showUninstallPreview = false
    @State private var workspaceTab: UninstallerWorkspaceTab = .applications
    @State private var remainingActionMessage: String?
    @State private var pendingRemainingOperation: RemainingOperation?

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: UninstallerViewModel(root: rootModel))
    }

    private var uninstallerState: UninstallerFeatureState {
        model.state
    }

    private var installedApps: [InstalledApp] {
        uninstallerState.installedApps
    }

    private var remnants: [AppRemnant] {
        uninstallerState.remnants
    }

    private var isUninstallerLoading: Bool {
        uninstallerState.isLoading
    }

    private var uninstallReport: UninstallValidationReport? {
        uninstallerState.uninstallReport
    }

    private var uninstallVerifyReport: UninstallVerifyReport? {
        uninstallerState.verifyReport
    }

    private var isUninstallVerifyRunning: Bool {
        uninstallerState.isVerifyRunning
    }

    private var uninstallSessions: [UninstallSession] {
        uninstallerState.sessions
    }

    private var remainingRecords: [UninstallRemainingRecord] {
        uninstallerState.remainingRecords
    }

    private var remainingIssueCount: Int {
        remainingRecords.reduce(0) { $0 + $1.remainingCount }
    }

    private var remainingTotalSizeText: String {
        let total = remainingRecords.reduce(Int64(0)) { $0 + $1.totalSizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var remnantTotalSizeText: String {
        let total = remnants.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var selectedApp: InstalledApp? {
        guard let selectedAppPath else { return nil }
        return installedApps.first { $0.appURL.path == selectedAppPath }
    }

    private var topRemnantsBySize: [AppRemnant] {
        remnants
            .sorted { $0.sizeInBytes > $1.sizeInBytes }
            .prefix(8)
            .map { $0 }
    }

    private var remnantCoverage: [(name: String, bytes: Int64)] {
        let groups = Dictionary(grouping: remnants) { remnant in
            let path = remnant.url.path.lowercased()
            if path.contains("/library/group containers/") || path.contains("/library/containers/") {
                return "Containers"
            }
            if path.contains("/library/caches/") {
                return "Caches"
            }
            if path.contains("/library/preferences/") {
                return "Preferences"
            }
            if path.contains("/library/application support/") {
                return "App Support"
            }
            if path.contains("/library/") {
                return "Library Other"
            }
            return "Other"
        }

        return groups.map { key, values in
            (name: key, bytes: values.reduce(0) { $0 + $1.sizeInBytes })
        }
        .sorted { $0.bytes > $1.bytes }
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

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing - 2) {
                header
                actionsToolbar
                workspaceNavigation
                if workspaceTab == .applications {
                    uninstallerInfographics
                }

                if workspaceTab == .applications {
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    applicationsSidebar
                    applicationsWorkspace
                }
                } else if workspaceTab == .rollback {
                    rollbackWorkspace
                } else {
                    remainingWorkspace
                }
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .onAppear {
            if installedApps.isEmpty {
                model.loadInstalledApps()
            }
            if selectedAppPath == nil {
                selectedAppPath = installedApps.first?.appURL.path
            }
        }
        .onChange(of: selectedAppPath) {
            guard let selectedApp else { return }
            model.loadRemnants(for: selectedApp)
        }
        .onChange(of: installedApps) {
            guard selectedAppPath == nil else { return }
            selectedAppPath = installedApps.first?.appURL.path
        }
        .onChange(of: workspaceTab) {
            guard workspaceTab == .remaining else { return }
            beginRemainingOperation(.scan)
        }
        .onChange(of: isUninstallerLoading) {
            guard workspaceTab == .remaining, !isUninstallerLoading, let pendingRemainingOperation else { return }
            remainingActionMessage = pendingRemainingOperation.completionMessage(
                appCount: remainingRecords.count,
                itemCount: remainingIssueCount,
                totalSizeText: remainingTotalSizeText
            )
            self.pendingRemainingOperation = nil
        }
        .sheet(isPresented: $showUninstallPreview) {
            if let selectedApp {
                UninstallPreviewSheet(
                    app: selectedApp,
                    previewItems: model.uninstallPreview(for: selectedApp),
                    onConfirm: { selectedItems in
                        let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: selectedApp.bundleID).isEmpty
                        model.uninstall(
                            app: selectedApp,
                            selectedItems: selectedItems,
                            isAppRunning: isRunning
                        ) { _ in
                            model.loadInstalledApps()
                        }
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
            EmptyView()
        }
    }

    private var actionsToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if workspaceTab == .applications {
                    GlassPillBadge(title: "\(filteredApps.count) apps", tint: .blue)
                    GlassPillBadge(title: "\(remnants.count) remnants", tint: .orange)

                    Button("Rescan Apps") {
                        model.loadInstalledApps()
                    }
                    .buttonStyle(.bordered)

                    Button("Open App Repair") {
                        model.openSection(.repair)
                    }
                    .buttonStyle(.bordered)

                    if let selectedApp {
                        Button("Uninstall Selected", role: .destructive) {
                            selectedAppPath = selectedApp.appURL.path
                            showUninstallPreview = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if workspaceTab == .rollback {
                    GlassPillBadge(title: "Sessions \(uninstallSessions.count)", tint: .blue)
                    GlassPillBadge(
                        title: "Recoverable \(uninstallSessions.reduce(0) { $0 + $1.rollbackItems.count })",
                        tint: .green
                    )
                } else {
                    GlassPillBadge(title: "\(remainingRecords.count) apps", tint: .blue)
                    GlassPillBadge(title: "\(remainingIssueCount) remaining", tint: .orange)
                    GlassPillBadge(title: remainingTotalSizeText, tint: .indigo)

                    Button("Scan Remaining") {
                        beginRemainingOperation(.scan)
                    }
                    .buttonStyle(.bordered)

                    Button("Deep Sweep") {
                        beginRemainingOperation(.deepSweep)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clean All Remaining", role: .destructive) {
                        let result = model.cleanAllRemainingRecords()
                        remainingActionMessage = "Moved \(result.moved) · Skipped \(result.skippedProtected.count) · Failed \(result.failed.count)"
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(remainingIssueCount == 0)

                    Button("Clear List", role: .destructive) {
                        model.clearRemainingRecords()
                        remainingActionMessage = "Remaining list cleared."
                    }
                    .buttonStyle(.bordered)
                    .disabled(remainingRecords.isEmpty)
                }
            }
            .padding(.horizontal, layoutMetrics.cardSpacing)
            .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        }
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text("Applications").tag(UninstallerWorkspaceTab.applications)
                Text("Rollback Sessions").tag(UninstallerWorkspaceTab.rollback)
                Text("Remaining").tag(UninstallerWorkspaceTab.remaining)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
            Spacer(minLength: 8)
        }
    }

    private func beginRemainingOperation(_ operation: RemainingOperation) {
        pendingRemainingOperation = operation
        remainingActionMessage = operation.inProgressMessage
        switch operation {
        case .scan:
            model.refreshRemainingRecords()
        case .deepSweep:
            model.deepSweepRemainingRecords()
        }
    }

    private var applicationsSidebar: some View {
        VStack(spacing: layoutMetrics.cardSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter applications", text: $appSearchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, layoutMetrics.cardSpacing)
            .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
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
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 260, maxHeight: .infinity)
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.04, shadowOpacity: 0.04, padding: 0)
        .overlay {
            if isUninstallerLoading {
                ProgressView("Loading apps...")
            }
        }
    }

    @ViewBuilder
    private var applicationsWorkspace: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            if let selectedApp {
                HStack(spacing: 10) {
                    Image(nsImage: iconCache.icon(for: selectedApp.appURL.path))
                        .resizable()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: layoutMetrics.cardSpacing)

                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            DRayIconBadge(icon: "folder.badge.minus", tint: .orange, size: 28)
                            Text("Remnant Footprint")
                                .font(.headline)
                            Spacer()
                            GlassPillBadge(title: "\(remnants.count) items", tint: .orange)
                            GlassPillBadge(title: remnantTotalSizeText, tint: .blue)
                        }
                        if remnantCoverage.isEmpty {
                            Text("No known leftovers found for the selected app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            let total = max(remnants.reduce(0) { $0 + $1.sizeInBytes }, 1)
                            ForEach(Array(remnantCoverage.prefix(5).enumerated()), id: \.offset) { index, row in
                                DRayRankedBarRow(
                                    rank: index + 1,
                                    title: row.name,
                                    subtitle: "Known Library/Application support locations",
                                    value: ByteCountFormatter.string(fromByteCount: row.bytes, countStyle: .file),
                                    progress: Double(row.bytes) / Double(total),
                                    tint: index == 0 ? .orange : .blue,
                                    icon: "folder.fill"
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(layoutMetrics.cardSpacing)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            DRayIconBadge(icon: "shield.checkered", tint: .green, size: 28)
                            Text("Safety")
                                .font(.headline)
                            Spacer()
                        }
                        DRayActionRow(
                            title: "Open App Repair",
                            subtitle: "Reset app data without uninstalling.",
                            icon: "wrench.and.screwdriver",
                            tint: .green,
                            actionTitle: "Open"
                        ) { model.openSection(.repair) }
                        if let report = uninstallReport {
                            DRayRankedBarRow(
                                rank: 1,
                                title: "Last uninstall",
                                subtitle: "Skipped \(report.skippedCount) · Failed \(report.failedCount)",
                                value: "Removed \(report.removedCount)",
                                progress: min(1, Double(report.removedCount) / Double(max(report.results.count, 1))),
                                tint: report.failedCount > 0 ? .red : .green,
                                icon: "checkmark.seal"
                            )
                        }
                    }
                    .frame(width: 330, alignment: .topLeading)
                    .padding(layoutMetrics.cardSpacing)
                    .glassSurface(cornerRadius: 18, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(remnants) { remnant in
                            remnantRow(remnant)
                        }
                    }
                    .padding(8)
                }
                .glassSurface(cornerRadius: 16, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: layoutMetrics.cardSpacing)
                .overlay {
                    if remnants.isEmpty && !isUninstallerLoading {
                        ContentUnavailableView(
                            "No remnants found",
                            systemImage: "checkmark.seal",
                            description: Text("Selected app has no removable leftovers in known locations.")
                        )
                    }
                }

                if let report = uninstallReport {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Validation report")
                            .font(.headline)
                        Text("Removed \(report.removedCount) · Skipped \(report.skippedCount) · Failed \(report.failedCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        uninstallReportSections(report)
                    }
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: layoutMetrics.cardSpacing)
                }

                if isUninstallVerifyRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Post-uninstall verify pass in progress...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(cornerRadius: 14, strokeOpacity: 0.05, shadowOpacity: 0.03, padding: layoutMetrics.cardSpacing)
                } else if let verify = uninstallVerifyReport {
                    uninstallVerifyPanel(verify, app: selectedApp)
                }
            } else {
                ContentUnavailableView("Uninstaller", systemImage: "trash", description: Text("Select app to inspect remnants."))
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summarySidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.headline)
            Text("Review footprint and remove leftovers safely.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                summaryMetric(title: "Applications", value: "\(installedApps.count)")
                summaryMetric(title: "Filtered", value: "\(filteredApps.count)")
                summaryMetric(title: "Detected remnants", value: "\(remnants.count)")
                summaryMetric(title: "Total size", value: remnantTotalSizeText)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let top = remnantCoverage.first, top.bytes > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary footprint")
                        .font(.subheadline.bold())
                    HStack {
                        Text(top.name)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: top.bytes, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    geometryBar(value: top.bytes, total: remnants.reduce(0) { $0 + $1.sizeInBytes }, tint: .orange)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !topRemnantsBySize.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Largest remnants")
                        .font(.subheadline.bold())
                    ForEach(topRemnantsBySize, id: \.id) { remnant in
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(remnant.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(ByteCountFormatter.string(fromByteCount: remnant.sizeInBytes, countStyle: .file))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                Text("No remnant footprint yet for the selected app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Spacer(minLength: 6)
        }
        .frame(minWidth: 250, idealWidth: 290, maxWidth: 320, maxHeight: .infinity, alignment: .top)
        .padding(10)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.04, shadowOpacity: 0.04, padding: 0)
    }

    private var rollbackWorkspace: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlassPillBadge(title: "Sessions \(uninstallSessions.count)", tint: .blue)
                GlassPillBadge(title: "Recoverable items \(uninstallSessions.reduce(0) { $0 + $1.rollbackItems.count })", tint: .green)
                Spacer(minLength: 8)
            }

            if uninstallSessions.isEmpty {
                ContentUnavailableView(
                    "No rollback sessions",
                    systemImage: "arrow.uturn.backward.circle",
                    description: Text("Run at least one uninstall to see recovery sessions.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(uninstallSessions.prefix(20))) { session in
                            rollbackSessionCard(session)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.05, shadowOpacity: 0.04, padding: 0)
    }

    private var remainingWorkspace: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlassPillBadge(title: "\(remainingRecords.count) apps", tint: .blue)
                GlassPillBadge(title: "\(remainingIssueCount) items", tint: .orange)
                GlassPillBadge(title: remainingTotalSizeText, tint: .indigo)
                Spacer(minLength: 8)
            }

            if let remainingActionMessage {
                Text(remainingActionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }

            if isUninstallerLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning remaining artifacts...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
            }

            if remainingRecords.isEmpty {
                ContentUnavailableView(
                    "No remaining artifacts",
                    systemImage: "checkmark.seal",
                    description: Text("After uninstall, unresolved tails appear here. Use Deep Sweep to detect orphaned leftovers from manually deleted apps.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(remainingRecords) { record in
                            remainingRecordCard(record)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.05, shadowOpacity: 0.04, padding: 0)
    }

    private func remainingRecordCard(_ record: UninstallRemainingRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.appName)
                        .font(.subheadline.bold())
                    Text("Updated \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                GlassPillBadge(title: "\(record.remainingCount) remaining", tint: .orange)
                GlassPillBadge(
                    title: ByteCountFormatter.string(fromByteCount: record.totalSizeInBytes, countStyle: .file),
                    tint: .indigo
                )
            }

            VStack(spacing: 6) {
                ForEach(record.issues.prefix(10)) { issue in
                    remainingIssueRow(issue)
                }
                if record.issues.count > 10 {
                    Text("+\(record.issues.count - 10) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            HStack(spacing: 8) {
                Button("Clean Remaining", role: .destructive) {
                    let result = model.cleanRemainingRecord(record)
                    remainingActionMessage = "\(record.appName): moved \(result.moved) · skipped \(result.skippedProtected.count) · failed \(result.failed.count)"
                }
                .buttonStyle(.borderedProminent)
                .disabled(record.issues.isEmpty)

                Button("Remove Record", role: .destructive) {
                    model.removeRemainingRecord(record)
                    remainingActionMessage = "Removed \(record.appName) from remaining list."
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func remainingIssueRow(_ issue: UninstallRemainingIssueRecord) -> some View {
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
                Text(issue.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(issue.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(ByteCountFormatter.string(fromByteCount: issue.sizeInBytes, countStyle: .file))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryMetric(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var uninstallerInfographics: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: layoutMetrics.cardSpacing) {
                uninstallerInfographicTiles
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(layoutMetrics.bottomStripVerticalPadding)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.06, shadowOpacity: 0.04, padding: 0)
    }

    @ViewBuilder
    private var uninstallerInfographicTiles: some View {
        infographicTile(
            title: "Installed",
            value: "\(installedApps.count)",
            subtitle: "apps",
            tint: .blue
        )
        infographicTile(
            title: "Filtered",
            value: "\(filteredApps.count)",
            subtitle: "visible",
            tint: .indigo
        )
        infographicTile(
            title: "Remnants",
            value: "\(remnants.count)",
            subtitle: remnantTotalSizeText,
            tint: .orange
        )
        infographicTile(
            title: "Sessions",
            value: "\(uninstallSessions.count)",
            subtitle: "rollback",
            tint: .green
        )
    }

    private func infographicTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: iconForInfographic(title))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, 5)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tint.opacity(0.16), lineWidth: 0.7))
        )
    }

    private func iconForInfographic(_ title: String) -> String {
        switch title {
        case "Installed": return "app.dashed"
        case "Filtered": return "line.3.horizontal.decrease.circle"
        case "Remnants": return "folder.badge.minus"
        case "Sessions": return "arrow.uturn.backward.circle"
        default: return "circle.grid.2x2"
        }
    }

    private func geometryBar(value: Int64, total: Int64, tint: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let ratio = total > 0 ? min(1, CGFloat(Double(value) / Double(total))) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.85), tint.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, width * ratio))
            }
        }
        .frame(height: 8)
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
                        .font(.subheadline.weight(.semibold))
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
                    let restored = model.restoreFromSession(session)
                    if restored.restoredCount > 0, let selectedApp {
                        model.loadRemnants(for: selectedApp)
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
                        let restored = model.restoreFromSession(session, item: item)
                        if restored.restoredCount > 0, let selectedApp {
                            model.loadRemnants(for: selectedApp)
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
                    let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
                    model.runVerifyPass(for: app, isAppRunning: isRunning)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Attempted \(verify.attemptedItems) · Removed \(verify.removedItems) · Remaining \(verify.remainingCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if verify.startupReferenceCount > 0 {
                Text("Startup references detected: \(verify.startupReferenceCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

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

            if !verify.startupReferences.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Potential relaunch sources")
                        .font(.subheadline.weight(.semibold))
                    ForEach(verify.startupReferences) { reference in
                        HStack(alignment: .top, spacing: 8) {
                            Text(reference.source.title)
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.14), in: Capsule())
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reference.displayPath)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(reference.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if let url = reference.url {
                                Button("Reveal") {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
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
                            if let category = row.failureCategory {
                                Text("Category: \(failureCategoryTitle(category))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            if let remediation = row.remediationHint, !remediation.isEmpty {
                                Text("Fix: \(remediation)")
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

    private func failureCategoryTitle(_ category: UninstallFailureCategory) -> String {
        switch category {
        case .permissionDenied: return "Permission Denied"
        case .appStoreManaged: return "App Store Managed"
        case .itemLocked: return "Locked/Immutable"
        case .readOnlyVolume: return "Read-only Volume"
        case .runningProcessLock: return "Running Process Lock"
        case .protectedBySystem: return "SIP/TCC Protected"
        case .unknown: return "Unknown"
        }
    }
}

private enum UninstallerWorkspaceTab: Hashable {
    case applications
    case rollback
    case remaining
}

private enum RemainingOperation {
    case scan
    case deepSweep

    var inProgressMessage: String {
        switch self {
        case .scan:
            return "Scanning remaining artifacts..."
        case .deepSweep:
            return "Deep sweep in progress: checking orphaned remnants in Library locations..."
        }
    }

    func completionMessage(appCount: Int, itemCount: Int, totalSizeText: String) -> String {
        switch self {
        case .scan:
            return "Remaining scan complete: \(appCount) apps, \(itemCount) items, \(totalSizeText)."
        case .deepSweep:
            return "Deep sweep complete: \(appCount) apps, \(itemCount) items, \(totalSizeText)."
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
