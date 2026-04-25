import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var model: RootViewModel
    @State private var isFolderPickerPresented = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    private let sections: [RootSectionItem] = [
        .init(id: .smartCare, icon: "sparkles"),
        .init(id: .clutter, icon: "square.on.square"),
        .init(id: .uninstaller, icon: "trash"),
        .init(id: .repair, icon: "wrench.and.screwdriver"),
        .init(id: .spaceLens, icon: "circle.grid.3x3.fill"),
        .init(id: .search, icon: "magnifyingglass"),
        .init(id: .performance, icon: "gauge.with.dots.needle.67percent"),
        .init(id: .privacy, icon: "lock.shield"),
        .init(id: .recovery, icon: "arrow.uturn.backward.circle"),
        .init(id: .settings, icon: "gearshape")
    ]

    var body: some View {
        GeometryReader { proxy in
            let adaptiveSidebarWidth = min(156, max(64, proxy.size.width * 0.102))
            let compactSidebar = adaptiveSidebarWidth < 118
            let sidebarWidth: CGFloat = compactSidebar ? 62 : adaptiveSidebarWidth

            ZStack {
                GlassShellBackground()

                HStack(spacing: 12) {
                    sidebarNavigation(isCompact: compactSidebar)
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .glassSurface(cornerRadius: 20, strokeOpacity: 0.18, shadowOpacity: 0.10, padding: 10)

                    VStack(alignment: .leading, spacing: 10) {
                        if model.permissions.firstLaunchNeedsSetup
                            && (!model.permissions.hasFolderPermission || !model.permissions.hasFullDiskAccess) {
                            permissionsOnboardingCard
                                .glassSurface(cornerRadius: 16, strokeOpacity: 0.14, shadowOpacity: 0.08, padding: 12)
                        }

                        sectionView(for: model.selectedSection)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .glassSurface(cornerRadius: 22, strokeOpacity: 0.14, shadowOpacity: 0.14, padding: 0)
                            .zIndex(1)
                    }
                }
                .padding(14)
            }
        }
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            model.selectFolder(url)
            model.refreshPermissions()
        }
        .alert(
            "Permissions Required",
            isPresented: Binding(
                get: { model.permissionBlockingMessage != nil },
                set: { if !$0 { model.clearPermissionBlockingMessage() } }
            )
        ) {
            Button("Grant Folder Access") {
                isFolderPickerPresented = true
            }
            Button("Open Full Disk Access") {
                model.permissions.openFullDiskAccessSettings()
            }
            Button("Restore") {
                model.restorePermissions()
            }
            Button("Cancel", role: .cancel) {
                model.clearPermissionBlockingMessage()
            }
        } message: {
            Text(model.permissionBlockingMessage ?? "")
        }
        .onAppear {
            model.refreshPermissions()
        }
        .onChange(of: scenePhase) {
            model.refreshPermissions()
        }
    }

    private func sidebarNavigation(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if isCompact {
                VStack(spacing: 4) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PremiumTheme.accent(colorScheme))
                    Text(compactSidebarVersionText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DiskRay")
                        .font(.title3.weight(.bold))
                    Text(model.appVersionDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sections) { item in
                        PremiumSidebarItem(
                            icon: item.icon,
                            title: model.localizedSectionTitle(for: item.id),
                            isSelected: model.selectedSection == item.id,
                            isCollapsed: isCompact
                        ) {
                            withAnimation(.snappy(duration: 0.18)) {
                                model.selectedSection = item.id
                            }
                        }
                        .accessibilityIdentifier("section-tab-\(item.id.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: model.permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundStyle(model.permissions.hasFullDiskAccess ? PremiumTheme.success : PremiumTheme.warning)
                if !isCompact {
                    Text(model.permissions.hasFullDiskAccess ? "Full Disk Access: On" : "Full Disk Access: Required")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .padding(.horizontal, isCompact ? 0 : 6)
            .padding(.bottom, 4)
            .help(model.permissions.hasFullDiskAccess ? "Full Disk Access: On" : "Full Disk Access: Required")
        }
    }

    private var permissionsOnboardingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Required")
                        .font(.headline)
                    Text("Grant DRay access once to enable scan, cleanup, uninstall and repair modules.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hide") {
                    if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
                        model.permissions.markOnboardingCompleted()
                    } else {
                        model.permissionBlockingMessage = "Finish permissions setup before hiding onboarding."
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                permissionStep(
                    title: "Folder Access",
                    granted: model.permissions.hasFolderPermission,
                    details: "Required for selected scan target."
                )
                permissionStep(
                    title: "Full Disk Access",
                    granted: model.permissions.hasFullDiskAccess,
                    details: "Required for full scan, privacy, uninstaller and repair."
                )
            }

            if let hint = model.permissions.permissionHint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Grant Folder Access") {
                    isFolderPickerPresented = true
                }
                .buttonStyle(.borderedProminent)

                Button("Open Full Disk Access") {
                    model.permissions.openFullDiskAccessSettings()
                }
                .buttonStyle(.bordered)

                Button("Refresh Status") {
                    model.refreshPermissions()
                }
                .buttonStyle(.bordered)

                Button("Restore") {
                    model.restorePermissions()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Finish Setup") {
                    model.refreshPermissions()
                    if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
                        model.permissions.markOnboardingCompleted()
                    } else {
                        model.permissionBlockingMessage = "Setup is incomplete. Grant both Folder Access and Full Disk Access."
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess))
            }
        }
    }

    private func permissionStep(title: String, granted: Bool, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: granted ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(granted ? Color.green : Color.orange)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var compactSidebarVersionText: String {
        let baseVersion = model.appVersionDisplay.split(separator: " ").first.map(String.init) ?? model.appVersionDisplay
        let parts = baseVersion.split(separator: ".")
        guard parts.count >= 2 else { return baseVersion }
        return "\(parts[0]).\(parts[1])"
    }

    @ViewBuilder
    private func sectionView(for section: AppSection) -> some View {
        switch section {
        case .smartCare:
            SmartCareView(rootModel: model)
        case .clutter:
            ClutterView(rootModel: model)
        case .uninstaller:
            UninstallerView(rootModel: model)
        case .repair:
            RepairView(model: model)
        case .spaceLens:
            SpaceLensView(
                model: model,
                onChooseFolder: { isFolderPickerPresented = true }
            )
        case .search:
            SearchView(rootModel: model)
        case .performance:
            PerformanceView(rootModel: model)
        case .privacy:
            PrivacyView(rootModel: model)
        case .recovery:
            RecoveryView(model: model)
        case .settings:
            SettingsView(
                model: model,
                onChooseFolder: { isFolderPickerPresented = true }
            )
        }
    }
}

private struct RootSectionItem: Identifiable {
    let id: AppSection
    let icon: String
}
