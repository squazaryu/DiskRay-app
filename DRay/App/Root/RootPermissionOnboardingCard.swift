import SwiftUI

struct RootPermissionOnboardingCard: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 10) {
                    DRayQuietIconBadge(systemName: "lock.shield", tone: .warning, size: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup Required")
                            .font(.headline)
                        Text("Grant DRay access once to enable scan, cleanup, uninstall and repair modules.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Hide") {
                    if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
                        model.permissions.markOnboardingCompleted()
                    } else {
                        model.permissionBlockingMessage = "Finish permissions setup before hiding onboarding."
                    }
                }
                .buttonStyle(DRaySecondaryButtonStyle())
                .controlSize(.small)
            }

            permissionSteps

            if let hint = model.permissions.permissionHint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            permissionActions
        }
    }

    private var permissionSteps: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                folderAccessStep
                fullDiskAccessStep
            }

            VStack(alignment: .leading, spacing: 8) {
                folderAccessStep
                fullDiskAccessStep
            }
        }
    }

    private var permissionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                grantFolderAccessButton
                openFullDiskAccessButton
                refreshStatusButton
                restoreButton
                Spacer()
                finishSetupButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    grantFolderAccessButton
                    openFullDiskAccessButton
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    refreshStatusButton
                    restoreButton
                    Spacer(minLength: 0)
                    finishSetupButton
                }
            }
        }
    }

    private var folderAccessStep: some View {
        permissionStep(
            title: "Folder Access",
            granted: model.permissions.hasFolderPermission,
            details: "Required for selected scan target."
        )
    }

    private var fullDiskAccessStep: some View {
        permissionStep(
            title: "Full Disk Access",
            granted: model.permissions.hasFullDiskAccess,
            details: "Required for full scan, privacy, uninstaller and repair."
        )
    }

    private var grantFolderAccessButton: some View {
        Button("Grant Folder Access") {
            onChooseFolder()
        }
        .buttonStyle(RootPermissionPrimaryButtonStyle())
    }

    private var openFullDiskAccessButton: some View {
        Button("Open Full Disk Access") {
            model.permissions.openFullDiskAccessSettings()
        }
        .buttonStyle(DRaySecondaryButtonStyle())
    }

    private var refreshStatusButton: some View {
        Button("Refresh Status") {
            model.refreshPermissionsAsync()
        }
        .buttonStyle(DRaySecondaryButtonStyle())
    }

    private var restoreButton: some View {
        Button("Restore") {
            model.restorePermissions()
        }
        .buttonStyle(DRaySecondaryButtonStyle())
    }

    private var finishSetupButton: some View {
        Button("Finish Setup") {
            model.refreshPermissions()
            if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
                model.permissions.markOnboardingCompleted()
            } else {
                model.permissionBlockingMessage = "Setup is incomplete. Grant both Folder Access and Full Disk Access."
            }
        }
        .buttonStyle(RootPermissionPrimaryButtonStyle())
        .disabled(!(model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess))
    }

    private func permissionStep(title: String, granted: Bool, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                DRayQuietIconBadge(
                    systemName: granted ? "checkmark.seal.fill" : "xmark.seal.fill",
                    tone: granted ? .success : .warning,
                    size: 22
                )
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calmGlass(.nestedCard, cornerRadius: 12)
    }
}

private struct RootPermissionPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .background(
                Capsule(style: .continuous)
                    .fill(primaryFill(configuration: configuration))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(primaryBorder, lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.86 : 1.0)
    }

    private func primaryFill(configuration: Configuration) -> Color {
        guard isEnabled else {
            return Color.primary.opacity(colorScheme == .dark ? 0.038 : 0.030)
        }
        return Color.accentColor.opacity(configuration.isPressed ? 0.135 : 0.105)
    }

    private var primaryBorder: Color {
        isEnabled ? Color.accentColor.opacity(0.24) : Color.primary.opacity(0.07)
    }
}
