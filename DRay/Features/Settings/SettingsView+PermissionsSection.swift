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
                fullDiskAccessDiagnostics(model.permissions.fullDiskAccessDiagnostic)

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

    private func fullDiskAccessDiagnostics(_ report: FullDiskAccessDiagnosticReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: fullDiskDiagnosticIcon(report.status))
                    .foregroundStyle(fullDiskDiagnosticTint(report.status))
                Text(tr("Диагностика Full Disk Access", "Full Disk Access diagnostics"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(fullDiskDiagnosticTitle(report.status))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(fullDiskDiagnosticTint(report.status))
            }

            ForEach(report.probes) { probe in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: probeStatusIcon(probe))
                        .font(.caption2)
                        .foregroundStyle(probeStatusTint(probe))
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(probe.path)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(probeStatusTitle(probe))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fullDiskDiagnosticTitle(_ status: FullDiskAccessDiagnosticStatus) -> String {
        switch status {
        case .likelyGranted:
            return tr("Похоже, выдано", "Likely granted")
        case .likelyMissing:
            return tr("Похоже, отсутствует", "Likely missing")
        case .partial:
            return tr("Частичный доступ", "Partial")
        case .unknown:
            return tr("Неизвестно", "Unknown")
        }
    }

    private func fullDiskDiagnosticIcon(_ status: FullDiskAccessDiagnosticStatus) -> String {
        switch status {
        case .likelyGranted:
            return "checkmark.seal.fill"
        case .likelyMissing:
            return "xmark.octagon.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private func fullDiskDiagnosticTint(_ status: FullDiskAccessDiagnosticStatus) -> Color {
        switch status {
        case .likelyGranted:
            return .green
        case .likelyMissing:
            return .red
        case .partial:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private func probeStatusTitle(_ probe: FullDiskAccessProbe) -> String {
        if probe.readable {
            return tr("Файл существует и читается", "Exists and readable")
        }
        if probe.denied {
            let base = tr("Файл существует, чтение запрещено", "Exists, read denied")
            if let error = probe.errorDescription, !error.isEmpty {
                return "\(base): \(error)"
            }
            return base
        }
        if !probe.exists {
            return tr("Файл не найден, probe не показателен", "Missing, probe is inconclusive")
        }
        return tr("Не удалось определить состояние", "Could not determine state")
    }

    private func probeStatusIcon(_ probe: FullDiskAccessProbe) -> String {
        if probe.readable { return "checkmark.circle.fill" }
        if probe.denied { return "xmark.circle.fill" }
        return "minus.circle.fill"
    }

    private func probeStatusTint(_ probe: FullDiskAccessProbe) -> Color {
        if probe.readable { return .green }
        if probe.denied { return .red }
        return .secondary
    }
}
