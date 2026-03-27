import Foundation
import OSLog

enum AppLogger {
    static let scanner = Logger(subsystem: "com.squazaryu.DRay", category: "scanner")
    static let permissions = Logger(subsystem: "com.squazaryu.DRay", category: "permissions")
    static let actions = Logger(subsystem: "com.squazaryu.DRay", category: "actions")
    static let telemetry = Logger(subsystem: "com.squazaryu.DRay", category: "telemetry")
}
