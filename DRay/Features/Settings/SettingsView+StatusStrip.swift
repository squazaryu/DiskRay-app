import SwiftUI

extension SettingsView {
    var settingsStatusStrip: some View {
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
