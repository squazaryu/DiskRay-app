import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ModuleHeaderCard(
                title: model.localized(.settingsTitle),
                subtitle: model.localized(.settingsSubtitle)
            ) {
                Button(model.localized(.settingsRefresh)) {
                    model.refreshPermissions()
                    model.refreshLaunchAtLoginStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 12) {
                    generalGroup
                    appearanceGroup
                    permissionsCard
                    scanningCleanupCard
                    recoverySafetyCard
                    diagnosticsCard
                }
                .padding(.horizontal, 2)

                settingsStatusStrip
                    .padding(.top, 12)
                    .padding(.horizontal, 2)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLoginStatus()
        }
    }

    private var settingsColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 360, maximum: 620), spacing: 12, alignment: .top)
        ]
    }

    private var settingsStatusStrip: some View {
        HStack(spacing: 8) {
            statusTile(
                title: model.localized(.settingsPermissions),
                value: permissionsStatusTitle,
                tint: permissionsStatusTint
            )
            statusTile(
                title: model.localized(.settingsAppearance),
                value: appearanceTitle(model.appAppearance),
                tint: .blue
            )
            statusTile(
                title: model.localized(.settingsLanguage),
                value: languageTitle(model.appLanguage),
                tint: .teal
            )
            statusTile(
                title: model.localized(.settingsVersion),
                value: model.appVersionDisplay,
                tint: .orange
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    private var permissionsStatusTitle: String {
        if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
            return tr("Готово", "Ready")
        }
        if model.permissions.hasFolderPermission || model.permissions.hasFullDiskAccess {
            return tr("Частично", "Partial")
        }
        return tr("Требуется доступ", "Action Needed")
    }

    var permissionsStatusTint: Color {
        if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
            return .green
        }
        if model.permissions.hasFolderPermission || model.permissions.hasFullDiskAccess {
            return .orange
        }
        return .red
    }
}
