import SwiftUI

struct RootSectionRouter: View {
    let section: AppSection
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    var body: some View {
        Group {
            switch section {
            case .overview:
                OverviewView(rootModel: model)
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
                    onChooseFolder: onChooseFolder
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
                    onChooseFolder: onChooseFolder
                )
            }
        }
        .environment(\.showFeatureHeader, true)
    }
}
