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
        if result.elevatedMoved > 0 {
            parts.append(t(
                "Через администратора: \(result.elevatedMoved)",
                "Admin authorized: \(result.elevatedMoved)"
            ))
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
            if !result.permissionFailures.isEmpty {
                if result.experimentalElevatedDeletionEnabled {
                    message += "\n" + t(
                        "Для части файлов была запрошена повышенная авторизация, но macOS всё равно отказала или запрос был отменён.",
                        "Elevated authorization was attempted for some files, but macOS still denied the operation or the prompt was canceled."
                    )
                } else {
                    message += "\n" + t(
                        "Часть файлов не защищена SIP, но текущий пользователь не может удалить их напрямую. В Settings можно включить экспериментальный полный доступ: DRay попробует перенос в Корзину через запрос администратора. SIP-пути это не обходит.",
                        "Some files are not SIP-protected, but the current user cannot delete them directly. Settings can enable Experimental Full Access: DRay will try Trash moves through administrator authorization. This does not bypass SIP paths."
                    )
                }
            }

            let sampleNames = result.failed
                .prefix(3)
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
            if !sampleNames.isEmpty {
                message += "\n" + t("Не удалось удалить: \(sampleNames)", "Could not remove: \(sampleNames)")
            }

            let reasonSamples = result.failed
                .compactMap { path -> String? in
                    guard let reason = result.failureReasons[path], !reason.isEmpty else { return nil }
                    return "\(URL(fileURLWithPath: path).lastPathComponent): \(reason)"
                }
                .prefix(2)
                .joined(separator: "\n")
            if !reasonSamples.isEmpty {
                message += "\n" + t("Причины:\n\(reasonSamples)", "Reasons:\n\(reasonSamples)")
            }
        }

        return message
    }
}
