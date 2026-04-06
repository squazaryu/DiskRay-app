import Foundation

@MainActor
protocol PermissionServicing: AnyObject {
    var permissionHint: String? { get }
    func canRunScan(target: URL?) -> Bool
    func canRunProtectedModule(actionName: String) -> Bool
    func canModify(urls: [URL], actionName: String, requiresFullDisk: Bool) -> Bool
}

extension AppPermissionService: PermissionServicing {}

struct PermissionGateDecision: Sendable, Equatable {
    let isAllowed: Bool
    let message: String?

    static let allowed = PermissionGateDecision(isAllowed: true, message: nil)

    static func blocked(_ message: String) -> PermissionGateDecision {
        PermissionGateDecision(isAllowed: false, message: message)
    }
}

@MainActor
struct PermissionGateUseCase {
    private let service: any PermissionServicing

    init(service: any PermissionServicing) {
        self.service = service
    }

    func canScan(target: URL?) -> PermissionGateDecision {
        guard service.canRunScan(target: target) else {
            return .blocked(service.permissionHint ?? "Additional permissions are required for scan.")
        }
        return .allowed
    }

    func canRunProtectedModule(actionName: String) -> PermissionGateDecision {
        guard service.canRunProtectedModule(actionName: actionName) else {
            return .blocked(service.permissionHint ?? "Full Disk Access is required for \(actionName).")
        }
        return .allowed
    }

    func canModify(
        urls: [URL],
        actionName: String,
        requiresFullDisk: Bool = false
    ) -> PermissionGateDecision {
        guard service.canModify(urls: urls, actionName: actionName, requiresFullDisk: requiresFullDisk) else {
            return .blocked(service.permissionHint ?? "Additional permissions are required for \(actionName).")
        }
        return .allowed
    }
}
