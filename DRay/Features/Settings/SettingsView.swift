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
                EmptyView()
            }

            settingsToolbar

            ScrollView {
                VStack(spacing: 12) {
                    generalGroup
                    permissionsCard
                    scanningCleanupCard
                    recoverySafetyCard
                    diagnosticsCard
                }
                .padding(12)
            }
        }
        .padding(12)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLoginStatus()
        }
    }

    private var settingsToolbar: some View {
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

    private var generalGroup: some View {
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

    private var permissionsCard: some View {
        sectionCard(
            title: model.localized(.settingsPermissions),
            subtitle: model.localized(.settingsPermissionsHint)
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

                if let permissionHint = model.permissions.permissionHint, !permissionHint.isEmpty {
                    Text(permissionHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

    private var scanningCleanupCard: some View {
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

    private var recoverySafetyCard: some View {
        sectionCard(
            title: model.localized(.settingsRecoverySafetySection),
            subtitle: model.localized(.settingsRecoverySafetyHint)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(model.localized(.settingsConfirmDestructiveActions), isOn: $model.confirmBeforeDestructiveActions)
                    .toggleStyle(.switch)

                Toggle(model.localized(.settingsConfirmStartupCleanup), isOn: $model.confirmBeforeStartupCleanup)
                    .toggleStyle(.switch)

                Toggle(model.localized(.settingsConfirmRepairFlows), isOn: $model.confirmBeforeRepairFlows)
                    .toggleStyle(.switch)

                Toggle(model.localized(.settingsAutoRescanAfterRestore), isOn: $model.autoRescanAfterRestore)
                    .toggleStyle(.switch)

                Divider()

                Button(model.localized(.settingsClearRecoveryHistory), role: .destructive) {
                    model.clearRecoveryHistory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var diagnosticsCard: some View {
        sectionCard(
            title: model.localized(.settingsDiagnosticsSection),
            subtitle: model.localized(.settingsDiagnosticsHint)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(model.localized(.settingsExportOperationLog)) {
                        _ = model.exportOperationLogReport()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(model.localized(.settingsExportDiagnosticReport)) {
                        _ = model.exportDiagnosticReport()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(model.localized(.settingsRevealCrashTelemetry)) {
                        model.revealCrashTelemetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Button(model.localized(.settingsClearCachedSnapshots)) {
                        model.clearCachedSnapshots()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(model.localized(.settingsResetSavedTargetBookmarks)) {
                        model.resetSavedTargetBookmark()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let exportedOps = model.lastExportedOperationLogURL {
                    Text("\(model.localized(.settingsLastOperationLogPath)): \(exportedOps.path)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let exportedDiagnostic = model.lastExportedDiagnosticURL {
                    Text("\(model.localized(.settingsLastDiagnosticReportPath)): \(exportedDiagnostic.path)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
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

    private func settingsRow<Content: View>(title: String, subtitle: String?, @ViewBuilder control: () -> Content) -> some View {
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

    private func permissionStatusRow(
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

    private func appearanceTitle(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system:
            return model.localized(.appearanceSystem)
        case .light:
            return model.localized(.appearanceLight)
        case .dark:
            return model.localized(.appearanceDark)
        }
    }

    private func scanTargetTitle(_ target: ScanDefaultTarget) -> String {
        switch target {
        case .startupDisk:
            return model.localized(.settingsScanTargetStartupDisk)
        case .home:
            return model.localized(.settingsScanTargetHome)
        case .lastSelectedFolder:
            return model.localized(.settingsScanTargetLastSelectedFolder)
        }
    }

    private func profileTitle(_ profile: SmartCleanProfile) -> String {
        switch profile {
        case .conservative:
            return model.localized(.settingsProfileConservative)
        case .balanced:
            return model.localized(.settingsProfileBalanced)
        case .aggressive:
            return model.localized(.settingsProfileAggressive)
        }
    }
}
