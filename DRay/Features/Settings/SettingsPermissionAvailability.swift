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
                severity: .limited
            ))

            items.append(SettingsPermissionImpactItem(
                id: "cleanup-write",
                feature: localized(
                    ru: "Очистка и удаление",
                    en: "Cleanup & Removal",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Очистка может частично пропускать элементы без доступа на запись в выбранных путях.",
                    en: "Cleanup can partially skip items without write access in selected paths.",
                    useRussian: useRussian
                ),
                severity: .limited
            ))
        }

        // Grounded in FeatureContext.allowProtectedModule(...) usage in feature controllers.
        if !hasFullDiskAccess {
            items.append(SettingsPermissionImpactItem(
                id: "smart-care",
                feature: "Smart Care",
                effect: localized(
                    ru: "Smart Scan может блокироваться и терять покрытие системных зон.",
                    en: "Smart Scan can be blocked and lose coverage for protected system areas.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "performance",
                feature: localized(
                    ru: "Производительность",
                    en: "Performance",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Performance Diagnostics может не запускаться полностью.",
                    en: "Performance Diagnostics may not run fully.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "privacy",
                feature: localized(
                    ru: "Приватность",
                    en: "Privacy",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Privacy Scan может быть ограничен или заблокирован.",
                    en: "Privacy Scan can be limited or blocked.",
                    useRussian: useRussian
                ),
                severity: .blocked
            ))

            items.append(SettingsPermissionImpactItem(
                id: "repair-uninstall",
                feature: localized(
                    ru: "Repair и Uninstaller",
                    en: "Repair & Uninstaller",
                    useRussian: useRussian
                ),
                effect: localized(
                    ru: "Доступ к системным remnant-путям и проверкам может быть неполным.",
                    en: "Access to protected remnant paths and verification checks can be incomplete.",
                    useRussian: useRussian
                ),
                severity: .limited
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
