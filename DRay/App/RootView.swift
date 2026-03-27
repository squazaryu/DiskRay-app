import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject private var model = RootViewModel()
    @State private var isFolderPickerPresented = false
    @State private var isHealthPopupPresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                SmartCareView(model: model)
                    .tabItem {
                        Label("Smart Care", systemImage: "sparkles")
                    }

                UninstallerView(model: model)
                    .tabItem {
                        Label("Uninstaller", systemImage: "trash")
                    }

                SpaceLensView(
                    model: model,
                    onChooseFolder: { isFolderPickerPresented = true }
                )
                .tabItem {
                    Label("Space Lens", systemImage: "circle.grid.3x3.fill")
                }

                SearchView(model: model)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                PerformanceView(model: model)
                    .tabItem {
                        Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
                    }

                PrivacyView(model: model)
                    .tabItem {
                        Label("Privacy", systemImage: "lock.shield")
                    }

                RecoveryView(model: model)
                    .tabItem {
                        Label("Recovery", systemImage: "arrow.uturn.backward.circle")
                    }
            }

            Button {
                isHealthPopupPresented = true
            } label: {
                Label("Health", systemImage: "heart.text.square.fill")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            model.selectFolder(url)
        }
        .sheet(isPresented: $isHealthPopupPresented) {
            HealthPopupView(model: model)
        }
    }
}
