import SwiftUI

extension SettingsView {
    var settingsToolbar: some View {
        HStack {
            Spacer()
            Button(model.localized(.settingsRefresh)) {
                model.refreshPermissions()
                model.refreshLaunchAtLoginStatus()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.10, shadowOpacity: 0.04, padding: 0)
    }

    func sectionCard<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    func settingsRow<Content: View>(title: String, subtitle: String?, @ViewBuilder control: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func permissionStatusRow(
        title: String,
        grantedText: String,
        missingText: String,
        granted: Bool,
        impactHint: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(granted ? model.localized(.settingsPermissionStatusGranted) : model.localized(.settingsPermissionStatusMissing))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(granted ? .green : .orange)
            }

            Text(granted ? grantedText : missingText)
                .font(.footnote)
                .foregroundStyle(granted ? .secondary : .primary)

            if let impactHint, !impactHint.isEmpty {
                Text(impactHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            return model.localized(.languageSystem)
        case .english:
            return model.localized(.languageEnglish)
        case .russian:
            return model.localized(.languageRussian)
        }
    }

    func appearanceTitle(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system:
            return model.localized(.appearanceSystem)
        case .light:
            return model.localized(.appearanceLight)
        case .dark:
            return model.localized(.appearanceDark)
        }
    }

    func scanTargetTitle(_ target: ScanDefaultTarget) -> String {
        switch target {
        case .startupDisk:
            return model.localized(.settingsScanTargetStartupDisk)
        case .home:
            return model.localized(.settingsScanTargetHome)
        case .lastSelectedFolder:
            return model.localized(.settingsScanTargetLastSelectedFolder)
        }
    }

    func profileTitle(_ profile: SmartCleanProfile) -> String {
        switch profile {
        case .conservative:
            return model.localized(.settingsProfileConservative)
        case .balanced:
            return model.localized(.settingsProfileBalanced)
        case .aggressive:
            return model.localized(.settingsProfileAggressive)
        }
    }

    func tr(_ ru: String, _ en: String) -> String {
        model.appLanguage.localeCode.lowercased().hasPrefix("ru") ? ru : en
    }
}
