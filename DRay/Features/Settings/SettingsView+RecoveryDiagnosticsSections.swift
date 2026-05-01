import SwiftUI

extension SettingsView {
    var recoverySafetyCard: some View {
        sectionCard(
            title: model.localized(.settingsRecoverySafetySection),
            subtitle: model.localized(.settingsRecoverySafetyHint),
            icon: "heart.shield",
            tint: .green
        ) {
            VStack(alignment: .leading, spacing: 10) {
                compactToggle(model.localized(.settingsConfirmDestructiveActions), isOn: $model.confirmBeforeDestructiveActions)

                compactToggle(model.localized(.settingsConfirmStartupCleanup), isOn: $model.confirmBeforeStartupCleanup)

                compactToggle(model.localized(.settingsConfirmRepairFlows), isOn: $model.confirmBeforeRepairFlows)

                compactToggle(model.localized(.settingsAutoRescanAfterRestore), isOn: $model.autoRescanAfterRestore)

                settingDivider()

                iconActionButton(model.localized(.settingsClearRecoveryHistory), systemImage: "trash", role: .destructive) {
                    model.clearRecoveryHistory()
                }
            }
        }
    }

    var diagnosticsCard: some View {
        sectionCard(
            title: model.localized(.settingsDiagnosticsSection),
            subtitle: model.localized(.settingsDiagnosticsHint),
            icon: "waveform.path.ecg",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 10) {
                compactActionGrid {
                    iconActionButton(model.localized(.settingsExportOperationLog), systemImage: "doc.text") {
                        _ = model.exportOperationLogReport()
                    }

                    iconActionButton(model.localized(.settingsExportDiagnosticReport), systemImage: "square.and.arrow.up") {
                        _ = model.exportDiagnosticReport()
                    }

                    iconActionButton(model.localized(.settingsRevealCrashTelemetry), systemImage: "ladybug") {
                        model.revealCrashTelemetry()
                    }

                    iconActionButton(model.localized(.settingsClearCachedSnapshots), systemImage: "xmark.bin") {
                        model.clearCachedSnapshots()
                    }

                    iconActionButton(model.localized(.settingsResetSavedTargetBookmarks), systemImage: "bookmark.slash") {
                        model.resetSavedTargetBookmark()
                    }
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
}
