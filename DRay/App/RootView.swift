import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var model: RootViewModel
    @State private var isFolderPickerPresented = false
    @Environment(\.scenePhase) private var scenePhase

    private let sections: [RootSectionItem] = [
        .init(id: .overview, icon: "gauge.open.with.lines.needle.33percent"),
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
            let effectiveSidebarMode = model.sidebarDisplayMode.resolved(for: proxy.size)
            let isCollapsed = effectiveSidebarMode == .collapsed
            let sidebarWidth: CGFloat = isCollapsed ? 46 : 236
            let effectiveDensity = model.appInterfaceDensity.resolved(for: proxy.size)
            let layoutMetrics = DRayLayoutMetrics.metrics(for: effectiveDensity)

            ZStack {
                GlassShellBackground()

                HStack(spacing: layoutMetrics.rootSpacing) {
                    RootSidebarView(
                        model: model,
                        sections: sections,
                        isCollapsed: isCollapsed
                    )
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .glassSurface(cornerRadius: 20, strokeOpacity: 0.16, shadowOpacity: 0.10, padding: 6)

                    VStack(alignment: .leading, spacing: 8) {
                        if model.permissions.firstLaunchNeedsSetup
                            && (!model.permissions.hasFolderPermission || !model.permissions.hasFullDiskAccess) {
                            RootPermissionOnboardingCard(
                                model: model,
                                onChooseFolder: { isFolderPickerPresented = true }
                            )
                                .glassSurface(cornerRadius: 16, strokeOpacity: 0.14, shadowOpacity: 0.08, padding: 12)
                        }

                        RootSectionRouter(
                            section: model.selectedSection,
                            model: model,
                            onChooseFolder: { isFolderPickerPresented = true }
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .zIndex(1)
                    }
                }
                .padding(layoutMetrics.rootPadding)
            }
            .environment(\.drayInterfaceDensity, effectiveDensity)
            .environment(\.drayLayoutMetrics, layoutMetrics)
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
}
