import Foundation

@MainActor
struct FeatureContext {
    let canRunProtectedModule: (_ actionName: String) -> PermissionGateDecision
    let canModify: (_ urls: [URL], _ actionName: String, _ requiresFullDisk: Bool) -> PermissionGateDecision
    let presentPermissionBlock: (_ message: String) -> Void
    let addOperationLog: (_ category: String, _ message: String) -> Void

    @discardableResult
    func allowProtectedModule(_ actionName: String) -> Bool {
        evaluate(canRunProtectedModule(actionName))
    }

    @discardableResult
    func allowModify(urls: [URL], actionName: String, requiresFullDisk: Bool) -> Bool {
        evaluate(canModify(urls, actionName, requiresFullDisk))
    }

    func log(category: String, message: String) {
        addOperationLog(category, message)
    }

    @discardableResult
    private func evaluate(_ decision: PermissionGateDecision) -> Bool {
        if decision.isAllowed { return true }
        presentPermissionBlock(
            decision.message ?? "Additional permissions are required for this action."
        )
        return false
    }
}
