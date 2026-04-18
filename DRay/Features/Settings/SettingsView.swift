import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ModuleHeaderCard(
                title: model.localized(.settingsTitle),
                subtitle: model.localized(.settingsSubtitle)
            ) {
                EmptyView()
            }

            settingsToolbar

            ScrollView {
                VStack(spacing: 12) {
                    generalGroup
                    permissionsCard
                    scanningCleanupCard
                    recoverySafetyCard
                    diagnosticsCard
                }
                .padding(12)
            }
        }
        .padding(12)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLoginStatus()
        }
    }
}
