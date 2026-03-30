import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var model: RootViewModel
    @State private var isFolderPickerPresented = false

    private let sections: [RootSectionItem] = [
        .init(id: .smartCare, title: "Smart Care", icon: "sparkles"),
        .init(id: .clutter, title: "My Clutter", icon: "square.on.square"),
        .init(id: .uninstaller, title: "Uninstaller", icon: "trash"),
        .init(id: .spaceLens, title: "Space Lens", icon: "circle.grid.3x3.fill"),
        .init(id: .search, title: "Search", icon: "magnifyingglass"),
        .init(id: .performance, title: "Performance", icon: "gauge.with.dots.needle.67percent"),
        .init(id: .privacy, title: "Privacy", icon: "lock.shield"),
        .init(id: .recovery, title: "Recovery", icon: "arrow.uturn.backward.circle")
    ]

    var body: some View {
        ZStack {
            GlassShellBackground()

            VStack(spacing: 12) {
                topNavigation
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
                        Label(item.title, systemImage: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .labelStyle(.titleOnly)
                    }
                    .buttonStyle(MinimalGlassButtonStyle(isActive: model.selectedSection == item.id))
                }
            }
            .padding(.horizontal, 4)
        }
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.2, shadowOpacity: 0.08, padding: 8)
    }

    @ViewBuilder
    private func sectionView(for section: AppSection) -> some View {
        switch section {
        case .smartCare:
            SmartCareView(model: model)
        case .clutter:
            ClutterView(model: model)
        case .uninstaller:
            UninstallerView(model: model)
        case .spaceLens:
            SpaceLensView(
                model: model,
                onChooseFolder: { isFolderPickerPresented = true }
            )
        case .search:
            SearchView(model: model)
        case .performance:
            PerformanceView(model: model)
        case .privacy:
            PrivacyView(model: model)
        case .recovery:
            RecoveryView(model: model)
        }
    }
}

private struct RootSectionItem: Identifiable {
    let id: AppSection
    let title: String
    let icon: String
}
