import SwiftUI

extension SettingsView {
    var generalGroup: some View {
        sectionCard(
            title: model.localized(.settingsGeneralSection),
            subtitle: model.localized(.settingsGeneralSectionHint),
            icon: "slider.horizontal.3",
            tint: .blue
        ) {
            VStack(spacing: 10) {
                settingsRow(title: model.localized(.settingsLanguage), subtitle: model.localized(.settingsLanguageHint)) {
                    Picker(model.localized(.settingsLanguage), selection: $model.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(languageTitle(language)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                settingDivider()

                settingsRow(title: model.localized(.settingsVersion), subtitle: model.localized(.settingsVersionHint)) {
                    Text(model.appVersionDisplay)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                settingDivider()

                settingsRow(title: model.localized(.settingsStartup), subtitle: nil) {
                    Toggle(
                        "",
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
                    .labelsHidden()
                    .accessibilityLabel(model.localized(.settingsLaunchAtLogin))
                }
            }
        }
    }

    var appearanceGroup: some View {
        sectionCard(
            title: model.localized(.settingsAppearance),
            subtitle: model.localized(.settingsAppearanceHint),
            icon: "paintbrush.pointed",
            tint: .purple
        ) {
            VStack(spacing: 10) {
                settingsRow(title: model.localized(.settingsAppearance), subtitle: nil) {
                    Picker(model.localized(.settingsAppearance), selection: $model.appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearanceTitle(appearance)).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                settingDivider()

                settingsRow(title: tr("Цвет акцента", "Accent color"), subtitle: tr("Применяется к навигации, кнопкам и системным индикаторам.", "Applies to navigation, controls and system indicators.")) {
                    HStack(spacing: 8) {
                        ForEach(AppAccentColor.allCases) { accent in
                            Button {
                                model.appAccentColor = accent
                            } label: {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(model.appAccentColor == accent ? 0.95 : 0.0), lineWidth: 2)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(accent.color.opacity(model.appAccentColor == accent ? 0.95 : 0.25), lineWidth: 1)
                                            .scaleEffect(model.appAccentColor == accent ? 1.34 : 1.0)
                                    )
                                    .shadow(color: accent.color.opacity(model.appAccentColor == accent ? 0.35 : 0.16), radius: 5, y: 2)
                            }
                            .buttonStyle(.plain)
                            .help(accent.title)
                        }
                        Spacer(minLength: 0)
                    }
                }

                settingDivider()

                settingsRow(title: tr("Плотность интерфейса", "Interface density"), subtitle: tr("Adaptive ужимает карточки при небольшом окне.", "Adaptive compresses cards when the window is smaller.")) {
                    Picker("Interface density", selection: $model.appInterfaceDensity) {
                        ForEach(AppInterfaceDensity.allCases) { density in
                            Text(interfaceDensityTitle(density)).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }

    var scanningCleanupCard: some View {
        sectionCard(
            title: model.localized(.settingsScanningCleanupSection),
            subtitle: model.localized(.settingsScanningCleanupHint),
            icon: "scope",
            tint: .cyan
        ) {
            VStack(alignment: .leading, spacing: 10) {
                settingsRow(title: model.localized(.settingsDefaultScanTarget), subtitle: nil) {
                    Picker(model.localized(.settingsDefaultScanTarget), selection: $model.defaultScanTarget) {
                        ForEach(ScanDefaultTarget.allCases) { target in
                            Text(scanTargetTitle(target)).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                settingDivider()

                compactToggle(model.localized(.settingsAutoRescanAfterCleanup), isOn: $model.autoRescanAfterCleanup)

                compactToggle(model.localized(.settingsIncludeHiddenByDefault), isOn: $model.includeHiddenByDefault)

                compactToggle(model.localized(.settingsIncludePackageContentsByDefault), isOn: $model.includePackageContentsByDefault)

                compactToggle(model.localized(.settingsExcludeTrashByDefault), isOn: $model.excludeTrashByDefault)

                settingDivider()

                settingsRow(title: model.localized(.settingsDefaultSmartCareProfile), subtitle: nil) {
                    Picker(model.localized(.settingsDefaultSmartCareProfile), selection: $model.defaultSmartCareProfile) {
                        ForEach(SmartCleanProfile.allCases) { profile in
                            Text(profileTitle(profile)).tag(profile)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }
}
