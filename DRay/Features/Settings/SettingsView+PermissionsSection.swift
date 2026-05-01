import SwiftUI

extension SettingsView {
    var permissionsCard: some View {
        sectionCard(
            title: model.localized(.settingsPermissions),
            subtitle: model.localized(.settingsPermissionsHint),
            icon: "lock.shield",
            tint: permissionsStatusTint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                permissionStatusRow(
                    title: model.localized(.settingsFolderAccessTitle),
                    grantedText: model.localized(.settingsFolderGranted),
                    missingText: model.localized(.settingsFolderDenied),
                    granted: model.permissions.hasFolderPermission,
                    impactHint: model.permissions.hasFolderPermission
                        ? nil
                        : model.localized(.settingsFolderAccessImpact)
                )

                permissionStatusRow(
                    title: model.localized(.settingsFullDiskAccessTitle),
                    grantedText: model.localized(.settingsFullDiskGranted),
                    missingText: model.localized(.settingsFullDiskDenied),
                    granted: model.permissions.hasFullDiskAccess,
                    impactHint: model.permissions.hasFullDiskAccess
                        ? nil
                        : model.localized(.settingsFullDiskAccessImpact)
                )

                if !permissionFeatureImpacts.isEmpty {
                    settingDivider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr(
                            "Что ограничено сейчас",
                            "What is limited right now"
                        ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        ForEach(permissionFeatureImpacts) { impact in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: impact.severity.symbol)
                                    .font(.caption)
                                    .foregroundStyle(impact.severity.tint)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(impact.feature)
                                        .font(.caption.weight(.semibold))
                                    Text(impact.effect)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let permissionHint = model.permissions.permissionHint, !permissionHint.isEmpty {
                    Text(permissionHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                compactActionGrid {
                    iconActionButton(model.localized(.settingsGrantFolder), systemImage: "folder.badge.plus") {
                        onChooseFolder()
                    }

                    iconActionButton(model.localized(.settingsOpenFullDisk), systemImage: "gearshape") {
                        model.permissions.openFullDiskAccessSettings()
                    }

                    iconActionButton(model.localized(.settingsRestore), systemImage: "arrow.clockwise") {
                        model.restorePermissions()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
