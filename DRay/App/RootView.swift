import SwiftUI

struct RootView: View {
    @StateObject private var model = RootViewModel()

    var body: some View {
        TabView {
            SpaceLensView(model: model)
                .tabItem {
                    Label("Space Lens", systemImage: "circle.grid.3x3.fill")
                }

            SearchView(model: model)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .onAppear {
            model.refresh()
        }
    }
}
