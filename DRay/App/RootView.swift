import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var model: RootViewModel
    @State private var isFolderPickerPresented = false
    @Environment(\.scenePhase) private var scenePhase

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
        ZStack {
            GlassShellBackground()

            VStack(spacing: 12) {
                topNavigation
                if model.permissions.firstLaunchNeedsSetup {
                    permissionsOnboardingCard
                        .glassSurface(cornerRadius: 18, strokeOpacity: 0.16, shadowOpacity: 0.12, padding: 12)
                }
                sectionView(for: model.selectedSection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassSurface(cornerRadius: 24, strokeOpacity: 0.16, shadowOpacity: 0.18, padding: 0)
            }
            .padding(14)
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

    private var topNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sections) { item in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            model.selectedSection = item.id
                        }
                    } label: {
                        Text(model.localizedSectionTitle(for: item.id))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 2)
                            .padding(.vertical, 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MinimalGlassButtonStyle(isActive: model.selectedSection == item.id))
                }
            }
            .padding(.horizontal, 4)
        }
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.2, shadowOpacity: 0.08, padding: 8)
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

    @ViewBuilder
    private func sectionView(for section: AppSection) -> some View {
        switch section {
        case .smartCare:
            SmartCareView(rootModel: model)
        case .clutter:
            ClutterView(model: model)
        case .uninstaller:
            UninstallerView(model: model)
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
            PrivacyView(model: model)
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
