import Foundation

enum RootTrashResultMessageFormatter {
    static func message(for result: TrashOperationResult, language: AppLanguage) -> String {
        let isRussian = language.localeCode.lowercased().hasPrefix("ru")
        func t(_ ru: String, _ en: String) -> String { isRussian ? ru : en }

        var parts: [String] = [t("Перемещено: \(result.moved)", "Moved: \(result.moved)")]
        if !result.skippedProtected.isEmpty {
            parts.append(t(
                "Пропущено (защищено macOS): \(result.skippedProtected.count)",
                "Skipped (macOS protected): \(result.skippedProtected.count)"
            ))
        }
        if !result.failed.isEmpty {
            parts.append(t("Ошибок: \(result.failed.count)", "Failed: \(result.failed.count)"))
        }

        var message = parts.joined(separator: ", ")

        if !result.skippedProtected.isEmpty {
            message += "\n" + t(
                "Системно-защищённые файлы (SIP/TCC) нельзя удалить обычным приложением, даже при Full Disk Access.",
                "System-protected files (SIP/TCC) cannot be deleted by a regular app, even with Full Disk Access."
            )
            let sampleNames = result.skippedProtected
                .prefix(3)
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
            if !sampleNames.isEmpty {
                message += "\n" + t("Примеры: \(sampleNames)", "Examples: \(sampleNames)")
            }
        }

        if !result.failed.isEmpty {
            let sampleNames = result.failed
                .prefix(3)
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
            if !sampleNames.isEmpty {
                message += "\n" + t("Не удалось удалить: \(sampleNames)", "Could not remove: \(sampleNames)")
            }
        }

        return message
    }
}
