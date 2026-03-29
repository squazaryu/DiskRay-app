import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var model: RootViewModel
    @State private var isFolderPickerPresented = false

    var body: some View {
        TabView(selection: $model.selectedSection) {
            SmartCareView(model: model)
                .tabItem {
                    Label("Smart Care", systemImage: "sparkles")
                }
                .tag(AppSection.smartCare)

            ClutterView(model: model)
                .tabItem {
                    Label("My Clutter", systemImage: "square.on.square")
                }
                .tag(AppSection.clutter)

            UninstallerView(model: model)
                .tabItem {
                    Label("Uninstaller", systemImage: "trash")
                }
                .tag(AppSection.uninstaller)

            SpaceLensView(
                model: model,
                onChooseFolder: { isFolderPickerPresented = true }
            )
            .tabItem {
                Label("Space Lens", systemImage: "circle.grid.3x3.fill")
            }
            .tag(AppSection.spaceLens)

            SearchView(model: model)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(AppSection.search)

            PerformanceView(model: model)
                .tabItem {
                    Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
                }
                .tag(AppSection.performance)

            PrivacyView(model: model)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
                .tag(AppSection.privacy)

            RecoveryView(model: model)
                .tabItem {
                    Label("Recovery", systemImage: "arrow.uturn.backward.circle")
                }
                .tag(AppSection.recovery)
        }
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            model.selectFolder(url)
        }
    }
}
