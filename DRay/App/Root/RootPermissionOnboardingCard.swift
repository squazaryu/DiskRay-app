import SwiftUI

struct RootPermissionOnboardingCard: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Required")
                        .font(.headline)
                    Text("Grant DRay access once to enable scan, cleanup, uninstall and repair modules.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hide") {
                    if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
                        model.permissions.markOnboardingCompleted()
                    } else {
                        model.permissionBlockingMessage = "Finish permissions setup before hiding onboarding."
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                permissionStep(
                    title: "Folder Access",
                    granted: model.permissions.hasFolderPermission,
                    details: "Required for selected scan target."
                )
                permissionStep(
                    title: "Full Disk Access",
                    granted: model.permissions.hasFullDiskAccess,
                    details: "Required for full scan, privacy, uninstaller and repair."
                )
            }

            if let hint = model.permissions.permissionHint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Grant Folder Access") {
                    onChooseFolder()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Full Disk Access") {
                    model.permissions.openFullDiskAccessSettings()
                }
                .buttonStyle(.bordered)

                Button("Refresh Status") {
                    model.refreshPermissions()
                }
                .buttonStyle(.bordered)

                Button("Restore") {
                    model.restorePermissions()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Finish Setup") {
                    model.refreshPermissions()
                    if model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess {
                        model.permissions.markOnboardingCompleted()
                    } else {
                        model.permissionBlockingMessage = "Setup is incomplete. Grant both Folder Access and Full Disk Access."
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(model.permissions.hasFolderPermission && model.permissions.hasFullDiskAccess))
            }
        }
    }

    private func permissionStep(title: String, granted: Bool, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: granted ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(granted ? Color.green : Color.orange)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
