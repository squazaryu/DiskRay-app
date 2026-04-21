import SwiftUI

struct SettingsPermissionImpactItem: Identifiable {
    enum Severity {
        case limited
        case blocked

        var symbol: String {
            switch self {
            case .limited: return "exclamationmark.circle.fill"
            case .blocked: return "xmark.octagon.fill"
            }
        }

        var tint: Color {
            switch self {
            case .limited: return .orange
            case .blocked: return .red
            }
        }
    }

    let id: String
    let feature: String
    let effect: String
    let severity: Severity
}

enum SettingsPermissionAvailabilityMap {
    static func impacts(hasFolderAccess: Bool, hasFullDiskAccess: Bool, useRussian: Bool) -> [SettingsPermissionImpactItem] {
        guard !(hasFolderAccess && hasFullDiskAccess) else { return [] }

        var items: [SettingsPermissionImpactItem] = []

        // Grounded in AppPermissionService.canRunScan(target:) and canModify(...)
        if !hasFolderAccess {
            items.append(SettingsPermissionImpactItem(
                id: "scan-target",
                feature: localized(
                    ru: "Сканирование цели",
                    en: "Target Scanning",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Сканирование вне выданной папки может блокироваться до повторной выдачи доступа.",
                    en: "Scanning outside the granted folder can be blocked until access is granted again.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "cleanup-write-scope",
                feature: localized(
                    ru: "Smart Clean / Duplicate Cleanup",
                    en: "Smart Clean / Duplicate Cleanup",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Очистка может частично пропускать файлы без доступа на запись в выбранных путях.",
                    en: "Cleanup can partially skip files without write access in selected paths.",
                    useRussian: useRussian
                ),
                severity: .limited
            ))
        }

        // Grounded in FeatureContext.allowProtectedModule(...) usage in feature controllers.
        if !hasFullDiskAccess {
            items.append(SettingsPermissionImpactItem(
                id: "performance-diagnostics",
                feature: localized(
                    ru: "Performance Diagnostics",
                    en: "Performance Diagnostics",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Запуск диагностики производительности блокируется до выдачи Full Disk Access.",
                    en: "Performance diagnostics are blocked until Full Disk Access is granted.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "privacy-scan",
                feature: localized(
                    ru: "Privacy Scan",
                    en: "Privacy Scan",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Скан приватности блокируется до выдачи Full Disk Access.",
                    en: "Privacy scan is blocked until Full Disk Access is granted.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "unified-scan",
                feature: localized(
                    ru: "Unified Scan",
                    en: "Unified Scan",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Объединённый скан блокируется до выдачи Full Disk Access.",
                    en: "Unified Scan is blocked until Full Disk Access is granted.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "repair-and-uninstall",
                feature: localized(
                    ru: "App Repair / Uninstall / Verify",
                    en: "App Repair / Uninstall / Verify",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Потоки ремонта и удаления (включая verify pass) блокируются до выдачи Full Disk Access.",
                    en: "Repair and uninstall flows (including verify pass) are blocked until Full Disk Access is granted.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "full-disk-cleanups",
                feature: localized(
                    ru: "Startup / Privacy Cleanup",
                    en: "Startup / Privacy Cleanup",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Очистка startup и privacy артефактов требует Full Disk Access и блокируется без него.",
                    en: "Startup and privacy cleanup actions require Full Disk Access and are blocked without it.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))
        }

        return items
    }

    private static func localized(ru: String, en: String, useRussian: Bool) -> String {
        useRussian ? ru : en
    }
}

extension SettingsView {
    var permissionFeatureImpacts: [SettingsPermissionImpactItem] {
        SettingsPermissionAvailabilityMap.impacts(
            hasFolderAccess: model.permissions.hasFolderPermission,
            hasFullDiskAccess: model.permissions.hasFullDiskAccess,
            useRussian: model.appLanguage.localeCode.lowercased().hasPrefix("ru")
        )
    }
}
