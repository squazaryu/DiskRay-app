import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case russian

    var id: String { rawValue }

    var localeCode: String {
        switch self {
        case .system:
            return Locale.preferredLanguages.first ?? "en"
        case .english:
            return "en"
        case .russian:
            return "ru"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum AppL10nKey: String {
    case navSmartCare
    case navClutter
    case navUninstaller
    case navRepair
    case navSpaceLens
    case navSearch
    case navPerformance
    case navPrivacy
    case navRecovery
    case navSettings

    case languageSystem
    case languageEnglish
    case languageRussian

    case settingsTitle
    case settingsSubtitle
    case settingsLanguage
    case settingsLanguageHint
    case settingsAppearance
    case settingsAppearanceHint
    case settingsVersion
    case settingsVersionHint
    case appearanceSystem
    case appearanceLight
    case appearanceDark
    case settingsStartup
    case settingsLaunchAtLogin
    case settingsPermissions
    case settingsPermissionsHint
    case settingsFolderGranted
    case settingsFolderDenied
    case settingsFullDiskGranted
    case settingsFullDiskDenied
    case settingsOpenFullDisk
    case settingsGrantFolder
    case settingsRestore
    case settingsRefresh
    case settingsGeneralSection
    case settingsGeneralSectionHint
    case settingsFolderAccessTitle
    case settingsFullDiskAccessTitle
    case settingsFolderAccessImpact
    case settingsFullDiskAccessImpact
    case settingsPermissionStatusGranted
    case settingsPermissionStatusMissing
    case settingsScanningCleanupSection
    case settingsScanningCleanupHint
    case settingsDefaultScanTarget
    case settingsScanTargetStartupDisk
    case settingsScanTargetHome
    case settingsScanTargetLastSelectedFolder
    case settingsAutoRescanAfterCleanup
    case settingsIncludeHiddenByDefault
    case settingsIncludePackageContentsByDefault
    case settingsExcludeTrashByDefault
    case settingsDefaultSmartCareProfile
    case settingsProfileConservative
    case settingsProfileBalanced
    case settingsProfileAggressive
    case settingsRecoverySafetySection
    case settingsRecoverySafetyHint
    case settingsConfirmDestructiveActions
    case settingsConfirmStartupCleanup
    case settingsConfirmRepairFlows
    case settingsAutoRescanAfterRestore
    case settingsClearRecoveryHistory
    case settingsDiagnosticsSection
    case settingsDiagnosticsHint
    case settingsExportOperationLog
    case settingsExportDiagnosticReport
    case settingsRevealCrashTelemetry
    case settingsClearCachedSnapshots
    case settingsResetSavedTargetBookmarks
    case settingsLastOperationLogPath
    case settingsLastDiagnosticReportPath

    case spaceLensTarget
    case spaceLensSelected
    case spaceLensNodes
    case spaceLensScan
    case spaceLensRescan
    case spaceLensTapMode
    case spaceLensPause
    case spaceLensResume
    case spaceLensCancel
    case spaceLensPermissions
    case spaceLensScanTarget
    case spaceLensLargest
    case spaceLensFolderGranted
    case spaceLensFolderDenied
    case spaceLensFullDiskGranted
    case spaceLensFullDiskDenied
    case spaceLensFirstLaunchRequired
    case spaceLensEmptyNeedSetup
    case spaceLensEmptyNeedScan
    case spaceLensScanning
    case spaceLensSelectedCount
    case spaceLensReveal
    case spaceLensOpen
    case spaceLensMoveToTrash
    case spaceLensClear
    case spaceLensTrashDialogTitle
    case spaceLensTrashDialogAction
    case spaceLensTrashResultTitle
    case spaceLensChooseFolder
    case spaceLensHome
    case spaceLensMacintoshHD

    case bubbleRoot
    case bubbleBack
    case bubbleRootName
    case bubbleHintSelect
    case bubbleHintOpen
    case bubbleTapModeSelect
    case bubbleTapModeOpenFolders

    case commonCancel
    case commonOK
}

enum AppL10n {
    static func text(_ key: AppL10nKey, language: AppLanguage) -> String {
        isRussian(language) ? russian(key) : english(key)
    }

    static func sectionTitle(_ section: AppSection, language: AppLanguage) -> String {
        switch section {
        case .smartCare: return text(.navSmartCare, language: language)
        case .clutter: return text(.navClutter, language: language)
        case .uninstaller: return text(.navUninstaller, language: language)
        case .repair: return text(.navRepair, language: language)
        case .spaceLens: return text(.navSpaceLens, language: language)
        case .search: return text(.navSearch, language: language)
        case .performance: return text(.navPerformance, language: language)
        case .privacy: return text(.navPrivacy, language: language)
        case .recovery: return text(.navRecovery, language: language)
        case .settings: return text(.navSettings, language: language)
        }
    }

    private static func isRussian(_ language: AppLanguage) -> Bool {
        language.localeCode.lowercased().hasPrefix("ru")
    }

    private static func english(_ key: AppL10nKey) -> String {
        switch key {
        case .navSmartCare: return "Smart Care"
        case .navClutter: return "My Clutter"
        case .navUninstaller: return "Uninstaller"
        case .navRepair: return "App Repair"
        case .navSpaceLens: return "Space Lens"
        case .navSearch: return "Search"
        case .navPerformance: return "Performance"
        case .navPrivacy: return "Privacy"
        case .navRecovery: return "Recovery"
        case .navSettings: return "Settings"

        case .languageSystem: return "System"
        case .languageEnglish: return "English"
        case .languageRussian: return "Russian"

        case .settingsTitle: return "Settings"
        case .settingsSubtitle: return "Global behavior, safety, scanning defaults and diagnostics controls."
        case .settingsLanguage: return "App Language"
        case .settingsLanguageHint: return "Applied instantly for localized modules."
        case .settingsAppearance: return "Interface Appearance"
        case .settingsAppearanceHint: return "Controls light/dark style for the main DRay window."
        case .settingsVersion: return "App Version"
        case .settingsVersionHint: return "Current installed DRay version."
        case .appearanceSystem: return "System"
        case .appearanceLight: return "Light"
        case .appearanceDark: return "Dark"
        case .settingsStartup: return "Startup"
        case .settingsLaunchAtLogin: return "Launch DRay at login"
        case .settingsPermissions: return "Permissions"
        case .settingsPermissionsHint: return "Keep both permissions granted for stable scan and cleanup."
        case .settingsFolderGranted: return "Folder access granted."
        case .settingsFolderDenied: return "Folder access is not granted."
        case .settingsFullDiskGranted: return "Full Disk Access granted."
        case .settingsFullDiskDenied: return "Full Disk Access is not granted."
        case .settingsOpenFullDisk: return "Open Full Disk Access"
        case .settingsGrantFolder: return "Grant Folder Access"
        case .settingsRestore: return "Restore"
        case .settingsRefresh: return "Refresh Status"
        case .settingsGeneralSection: return "General"
        case .settingsGeneralSectionHint: return "Core app behavior and startup preferences."
        case .settingsFolderAccessTitle: return "Folder Access"
        case .settingsFullDiskAccessTitle: return "Full Disk Access"
        case .settingsFolderAccessImpact: return "Smart Care coverage and cleanup actions may be limited for non-selected folders."
        case .settingsFullDiskAccessImpact: return "Search visibility, Smart Care coverage and diagnostics depth may be reduced."
        case .settingsPermissionStatusGranted: return "Granted"
        case .settingsPermissionStatusMissing: return "Missing"
        case .settingsScanningCleanupSection: return "Scanning & Cleanup"
        case .settingsScanningCleanupHint: return "Global defaults for target scope, scan filters and Smart Care profile."
        case .settingsDefaultScanTarget: return "Default Scan Target"
        case .settingsScanTargetStartupDisk: return "Startup Disk"
        case .settingsScanTargetHome: return "Home"
        case .settingsScanTargetLastSelectedFolder: return "Last Selected Folder"
        case .settingsAutoRescanAfterCleanup: return "Auto-rescan after cleanup actions"
        case .settingsIncludeHiddenByDefault: return "Include hidden files by default"
        case .settingsIncludePackageContentsByDefault: return "Include package contents by default"
        case .settingsExcludeTrashByDefault: return "Exclude Trash by default"
        case .settingsDefaultSmartCareProfile: return "Default Smart Care Profile"
        case .settingsProfileConservative: return "Conservative"
        case .settingsProfileBalanced: return "Balanced"
        case .settingsProfileAggressive: return "Aggressive"
        case .settingsRecoverySafetySection: return "Recovery & Safety"
        case .settingsRecoverySafetyHint: return "Confirmation policy and restore behavior controls."
        case .settingsConfirmDestructiveActions: return "Ask confirmation before destructive actions"
        case .settingsConfirmStartupCleanup: return "Ask confirmation before startup cleanup"
        case .settingsConfirmRepairFlows: return "Ask confirmation before repair/reset flows"
        case .settingsAutoRescanAfterRestore: return "Auto-rescan after restore"
        case .settingsClearRecoveryHistory: return "Clear recovery history"
        case .settingsDiagnosticsSection: return "Diagnostics"
        case .settingsDiagnosticsHint: return "Support and maintenance tools for diagnostics and state resets."
        case .settingsExportOperationLog: return "Export operation log"
        case .settingsExportDiagnosticReport: return "Export diagnostic report"
        case .settingsRevealCrashTelemetry: return "Reveal crash telemetry"
        case .settingsClearCachedSnapshots: return "Clear cached snapshots"
        case .settingsResetSavedTargetBookmarks: return "Reset saved target bookmarks"
        case .settingsLastOperationLogPath: return "Last operation log"
        case .settingsLastDiagnosticReportPath: return "Last diagnostic report"

        case .spaceLensTarget: return "Target"
        case .spaceLensSelected: return "Selected"
        case .spaceLensNodes: return "Nodes"
        case .spaceLensScan: return "Scan"
        case .spaceLensRescan: return "Rescan"
        case .spaceLensTapMode: return "Tap Mode"
        case .spaceLensPause: return "Pause"
        case .spaceLensResume: return "Resume"
        case .spaceLensCancel: return "Cancel"
        case .spaceLensPermissions: return "Permissions"
        case .spaceLensScanTarget: return "Scan Target"
        case .spaceLensLargest: return "Largest"
        case .spaceLensFolderGranted: return "Folder access granted for selected target."
        case .spaceLensFolderDenied: return "Folder access is not granted for current target."
        case .spaceLensFullDiskGranted: return "Full Disk Access granted."
        case .spaceLensFullDiskDenied: return "Full Disk Access is not granted."
        case .spaceLensFirstLaunchRequired: return "First launch setup is required before full functionality."
        case .spaceLensEmptyNeedSetup: return "Grant access and choose folder for first scan."
        case .spaceLensEmptyNeedScan: return "Choose a target and start scan."
        case .spaceLensScanning: return "Scanning"
        case .spaceLensSelectedCount: return "Selected"
        case .spaceLensReveal: return "Reveal"
        case .spaceLensOpen: return "Open"
        case .spaceLensMoveToTrash: return "Move to Trash"
        case .spaceLensClear: return "Clear"
        case .spaceLensTrashDialogTitle: return "Move selected item(s) to Trash?"
        case .spaceLensTrashDialogAction: return "Move to Trash"
        case .spaceLensTrashResultTitle: return "Trash Result"
        case .spaceLensChooseFolder: return "Choose folder..."
        case .spaceLensHome: return "Home"
        case .spaceLensMacintoshHD: return "Macintosh HD"

        case .bubbleRoot: return "Root"
        case .bubbleBack: return "Back"
        case .bubbleRootName: return "Root"
        case .bubbleHintSelect: return "Tap bubble: select item"
        case .bubbleHintOpen: return "Tap folder bubble: open level"
        case .bubbleTapModeSelect: return "Select"
        case .bubbleTapModeOpenFolders: return "Open folders"

        case .commonCancel: return "Cancel"
        case .commonOK: return "OK"
        }
    }

    private static func russian(_ key: AppL10nKey) -> String {
        switch key {
        case .navSmartCare: return "Умный уход"
        case .navClutter: return "Мой хлам"
        case .navUninstaller: return "Удаление"
        case .navRepair: return "Починка"
        case .navSpaceLens: return "Space Lens"
        case .navSearch: return "Поиск"
        case .navPerformance: return "Производительность"
        case .navPrivacy: return "Приватность"
        case .navRecovery: return "Восстановление"
        case .navSettings: return "Настройки"

        case .languageSystem: return "Системный"
        case .languageEnglish: return "English"
        case .languageRussian: return "Русский"

        case .settingsTitle: return "Настройки"
        case .settingsSubtitle: return "Глобальное поведение, безопасность, defaults сканирования и диагностика."
        case .settingsLanguage: return "Язык интерфейса"
        case .settingsLanguageHint: return "Применяется сразу для локализованных модулей."
        case .settingsAppearance: return "Тема интерфейса"
        case .settingsAppearanceHint: return "Определяет светлый/тёмный стиль главного окна DRay."
        case .settingsVersion: return "Версия приложения"
        case .settingsVersionHint: return "Текущая установленная версия DRay."
        case .appearanceSystem: return "Системная"
        case .appearanceLight: return "Светлая"
        case .appearanceDark: return "Тёмная"
        case .settingsStartup: return "Запуск"
        case .settingsLaunchAtLogin: return "Запускать DRay при входе"
        case .settingsPermissions: return "Разрешения"
        case .settingsPermissionsHint: return "Для стабильного сканирования и очистки нужны оба разрешения."
        case .settingsFolderGranted: return "Доступ к папке выдан."
        case .settingsFolderDenied: return "Доступ к папке не выдан."
        case .settingsFullDiskGranted: return "Полный доступ к диску выдан."
        case .settingsFullDiskDenied: return "Полный доступ к диску не выдан."
        case .settingsOpenFullDisk: return "Открыть Full Disk Access"
        case .settingsGrantFolder: return "Выдать доступ к папке"
        case .settingsRestore: return "Восстановить"
        case .settingsRefresh: return "Обновить статус"
        case .settingsGeneralSection: return "Общие"
        case .settingsGeneralSectionHint: return "Базовое поведение приложения и параметры запуска."
        case .settingsFolderAccessTitle: return "Доступ к папке"
        case .settingsFullDiskAccessTitle: return "Полный доступ к диску"
        case .settingsFolderAccessImpact: return "Покрытие Smart Care и действия очистки могут быть ограничены вне выбранной папки."
        case .settingsFullDiskAccessImpact: return "Видимость поиска, покрытие Smart Care и глубина диагностики могут быть ограничены."
        case .settingsPermissionStatusGranted: return "Выдано"
        case .settingsPermissionStatusMissing: return "Отсутствует"
        case .settingsScanningCleanupSection: return "Сканирование и очистка"
        case .settingsScanningCleanupHint: return "Глобальные defaults для цели сканирования, фильтров и профиля Smart Care."
        case .settingsDefaultScanTarget: return "Цель сканирования по умолчанию"
        case .settingsScanTargetStartupDisk: return "Системный диск"
        case .settingsScanTargetHome: return "Домашняя папка"
        case .settingsScanTargetLastSelectedFolder: return "Последняя выбранная папка"
        case .settingsAutoRescanAfterCleanup: return "Автоперескан после очистки"
        case .settingsIncludeHiddenByDefault: return "Включать скрытые файлы по умолчанию"
        case .settingsIncludePackageContentsByDefault: return "Включать содержимое пакетов по умолчанию"
        case .settingsExcludeTrashByDefault: return "Исключать Корзину по умолчанию"
        case .settingsDefaultSmartCareProfile: return "Профиль Smart Care по умолчанию"
        case .settingsProfileConservative: return "Осторожный"
        case .settingsProfileBalanced: return "Сбалансированный"
        case .settingsProfileAggressive: return "Агрессивный"
        case .settingsRecoverySafetySection: return "Восстановление и безопасность"
        case .settingsRecoverySafetyHint: return "Политика подтверждений и поведение после восстановления."
        case .settingsConfirmDestructiveActions: return "Запрашивать подтверждение перед разрушительными действиями"
        case .settingsConfirmStartupCleanup: return "Запрашивать подтверждение перед очисткой автозапуска"
        case .settingsConfirmRepairFlows: return "Запрашивать подтверждение перед repair/reset сценариями"
        case .settingsAutoRescanAfterRestore: return "Автоперескан после восстановления"
        case .settingsClearRecoveryHistory: return "Очистить историю восстановления"
        case .settingsDiagnosticsSection: return "Диагностика"
        case .settingsDiagnosticsHint: return "Инструменты поддержки и обслуживания для отчётов и сброса вспомогательных данных."
        case .settingsExportOperationLog: return "Экспортировать operation log"
        case .settingsExportDiagnosticReport: return "Экспортировать diagnostic report"
        case .settingsRevealCrashTelemetry: return "Показать crash telemetry"
        case .settingsClearCachedSnapshots: return "Очистить кеш snapshot-ов"
        case .settingsResetSavedTargetBookmarks: return "Сбросить сохранённые bookmark-цели"
        case .settingsLastOperationLogPath: return "Последний operation log"
        case .settingsLastDiagnosticReportPath: return "Последний diagnostic report"

        case .spaceLensTarget: return "Цель"
        case .spaceLensSelected: return "Выбрано"
        case .spaceLensNodes: return "Узлов"
        case .spaceLensScan: return "Сканировать"
        case .spaceLensRescan: return "Пересканировать"
        case .spaceLensTapMode: return "Режим клика"
        case .spaceLensPause: return "Пауза"
        case .spaceLensResume: return "Продолжить"
        case .spaceLensCancel: return "Отмена"
        case .spaceLensPermissions: return "Разрешения"
        case .spaceLensScanTarget: return "Цель сканирования"
        case .spaceLensLargest: return "Крупные"
        case .spaceLensFolderGranted: return "Доступ к выбранной папке выдан."
        case .spaceLensFolderDenied: return "Доступ к текущей папке не выдан."
        case .spaceLensFullDiskGranted: return "Полный доступ к диску выдан."
        case .spaceLensFullDiskDenied: return "Полный доступ к диску не выдан."
        case .spaceLensFirstLaunchRequired: return "Для первого запуска нужно выдать разрешения."
        case .spaceLensEmptyNeedSetup: return "Выдай доступ и выбери папку для первого скана."
        case .spaceLensEmptyNeedScan: return "Выбери цель и запусти сканирование."
        case .spaceLensScanning: return "Сканирование"
        case .spaceLensSelectedCount: return "Выбрано"
        case .spaceLensReveal: return "Показать"
        case .spaceLensOpen: return "Открыть"
        case .spaceLensMoveToTrash: return "В корзину"
        case .spaceLensClear: return "Очистить"
        case .spaceLensTrashDialogTitle: return "Переместить выбранные элементы в корзину?"
        case .spaceLensTrashDialogAction: return "Переместить в корзину"
        case .spaceLensTrashResultTitle: return "Результат удаления"
        case .spaceLensChooseFolder: return "Выбрать папку..."
        case .spaceLensHome: return "Домашняя"
        case .spaceLensMacintoshHD: return "Macintosh HD"

        case .bubbleRoot: return "Корень"
        case .bubbleBack: return "Назад"
        case .bubbleRootName: return "Корень"
        case .bubbleHintSelect: return "Нажми на пузырь: выбрать объект"
        case .bubbleHintOpen: return "Нажми на папку: открыть уровень"
        case .bubbleTapModeSelect: return "Выбор"
        case .bubbleTapModeOpenFolders: return "Открывать папки"

        case .commonCancel: return "Отмена"
        case .commonOK: return "ОК"
        }
    }
}
