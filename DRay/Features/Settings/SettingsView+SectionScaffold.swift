import SwiftUI

extension SettingsView {
    func sectionCard<Content: View>(
        title: String,
        subtitle: String?,
        icon: String? = nil,
        tint: Color = .blue,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 9) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(tint.opacity(0.13), in: Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.10, shadowOpacity: 0.06, padding: 14)
    }

    func settingsRow<Content: View>(title: String, subtitle: String?, @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .frame(maxWidth: 360, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }

    func compactToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.switch)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func compactActionGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            content()
        }
    }

    func settingDivider() -> some View {
        Divider()
            .opacity(0.55)
    }

    func iconActionButton(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
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

    func interfaceDensityTitle(_ density: AppInterfaceDensity) -> String {
        switch density {
        case .adaptive:
            return tr("Авто", "Adaptive")
        case .comfortable:
            return tr("Обычный", "Comfortable")
        case .compact:
            return tr("Компактный", "Compact")
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

    func statusTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
