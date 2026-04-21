import SwiftUI

extension SettingsView {
    var recoverySafetyCard: some View {
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

    var diagnosticsCard: some View {
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
}
