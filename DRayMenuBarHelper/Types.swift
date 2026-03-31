import Foundation

enum AppSection: String {
    case smartCare
    case clutter
    case uninstaller
    case repair
    case spaceLens
    case search
    case performance
    case privacy
    case recovery
}

enum AppLaunchAction: String {
    case runUnifiedScan = "run-unified-scan"
    case runPerformanceScan = "run-performance-scan"
    case scanDuplicatesHome = "scan-duplicates-home"
    case runSpaceLensScan = "run-space-lens-scan"
}

enum AppIPC {
    static let openSectionName = Notification.Name("com.squazaryu.dray.open-section")
    static let quitCompletelyName = Notification.Name("com.squazaryu.dray.quit-completely")
    static let sectionKey = "section"
    static let actionKey = "action"
}

struct HelperConfig {
    var appPath: String = "/Applications/DRay.app"
    var startupSection: AppSection?

    init(arguments: [String]) {
        appPath = HelperConfig.resolveDefaultAppPath()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--app-path":
                if index + 1 < arguments.count {
                    appPath = arguments[index + 1]
                    index += 1
                }
            case "--open-section":
                if index + 1 < arguments.count {
                    startupSection = AppSection(rawValue: arguments[index + 1])
                    index += 1
                }
            default:
                break
            }
            index += 1
        }
    }

    private static func resolveDefaultAppPath() -> String {
        let executablePath = CommandLine.arguments.first ?? ""
        let marker = "/Contents/Helpers/"
        if let range = executablePath.range(of: marker) {
            return String(executablePath[..<range.lowerBound])
        }
        return "/Applications/DRay.app"
    }
}
