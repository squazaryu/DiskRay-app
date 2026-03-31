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
                Button(model.localized(.settingsRefresh)) {
                    model.refreshPermissions()
                    model.refreshLaunchAtLoginStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView {
                VStack(spacing: 12) {
                    languageCard
                    startupCard
                    permissionsCard
                }
                .padding(8)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLoginStatus()
        }
    }

    private var languageCard: some View {
        sectionCard(title: model.localized(.settingsLanguage), subtitle: model.localized(.settingsLanguageHint)) {
            Picker(
                model.localized(.settingsLanguage),
                selection: $model.appLanguage
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(languageTitle(language))
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
        }
    }

    private var startupCard: some View {
        sectionCard(title: model.localized(.settingsStartup), subtitle: nil) {
            Toggle(
                model.localized(.settingsLaunchAtLogin),
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { desired in
                        if desired != model.launchAtLoginEnabled {
                            model.toggleLaunchAtLogin()
                        }
                    }
                )
            )
            .toggleStyle(.switch)
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    private var permissionsCard: some View {
        sectionCard(title: model.localized(.settingsPermissions), subtitle: model.localized(.settingsPermissionsHint)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.permissions.hasFolderPermission
                     ? model.localized(.settingsFolderGranted)
                     : model.localized(.settingsFolderDenied))
                .font(.footnote)
                .foregroundStyle(model.permissions.hasFolderPermission ? .green : .orange)

                Text(model.permissions.hasFullDiskAccess
                     ? model.localized(.settingsFullDiskGranted)
                     : model.localized(.settingsFullDiskDenied))
                .font(.footnote)
                .foregroundStyle(model.permissions.hasFullDiskAccess ? .green : .orange)

                HStack(spacing: 8) {
                    Button(model.localized(.settingsGrantFolder)) {
                        onChooseFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(model.localized(.settingsOpenFullDisk)) {
                        model.permissions.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(model.localized(.settingsRestore)) {
                        model.restorePermissions()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionCard<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
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

    private func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            return model.localized(.languageSystem)
        case .english:
            return model.localized(.languageEnglish)
        case .russian:
            return model.localized(.languageRussian)
        }
    }
}

