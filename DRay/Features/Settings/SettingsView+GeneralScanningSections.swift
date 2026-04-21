import SwiftUI

extension SettingsView {
    var generalGroup: some View {
        sectionCard(
            title: model.localized(.settingsGeneralSection),
            subtitle: model.localized(.settingsGeneralSectionHint)
        ) {
            VStack(spacing: 12) {
                settingsRow(title: model.localized(.settingsLanguage), subtitle: model.localized(.settingsLanguageHint)) {
                    Picker(model.localized(.settingsLanguage), selection: $model.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(languageTitle(language)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                }

                Divider()

                settingsRow(title: model.localized(.settingsAppearance), subtitle: model.localized(.settingsAppearanceHint)) {
                    Picker(model.localized(.settingsAppearance), selection: $model.appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearanceTitle(appearance)).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                }

                Divider()

                settingsRow(title: model.localized(.settingsVersion), subtitle: model.localized(.settingsVersionHint)) {
                    Text(model.appVersionDisplay)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                settingsRow(title: model.localized(.settingsStartup), subtitle: nil) {
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
        }
    }

    var scanningCleanupCard: some View {
        sectionCard(
            title: model.localized(.settingsScanningCleanupSection),
            subtitle: model.localized(.settingsScanningCleanupHint)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                settingsRow(title: model.localized(.settingsDefaultScanTarget), subtitle: nil) {
                    Picker(model.localized(.settingsDefaultScanTarget), selection: $model.defaultScanTarget) {
                        ForEach(ScanDefaultTarget.allCases) { target in
                            Text(scanTargetTitle(target)).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                }

                Toggle(model.localized(.settingsAutoRescanAfterCleanup), isOn: $model.autoRescanAfterCleanup)
                    .toggleStyle(.switch)

                Toggle(model.localized(.settingsIncludeHiddenByDefault), isOn: $model.includeHiddenByDefault)
                    .toggleStyle(.switch)

                Toggle(model.localized(.settingsIncludePackageContentsByDefault), isOn: $model.includePackageContentsByDefault)
                    .toggleStyle(.switch)

                Toggle(model.localized(.settingsExcludeTrashByDefault), isOn: $model.excludeTrashByDefault)
                    .toggleStyle(.switch)

                settingsRow(title: model.localized(.settingsDefaultSmartCareProfile), subtitle: nil) {
                    Picker(model.localized(.settingsDefaultSmartCareProfile), selection: $model.defaultSmartCareProfile) {
                        ForEach(SmartCleanProfile.allCases) { profile in
                            Text(profileTitle(profile)).tag(profile)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                }
            }
        }
    }
}
