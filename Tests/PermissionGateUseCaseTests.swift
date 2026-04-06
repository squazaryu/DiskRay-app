import Foundation
import Testing
@testable import DRay

@MainActor
struct PermissionGateUseCaseTests {
    @Test
    func canScanReturnsAllowedWhenServiceAllows() {
        let service = PermissionServiceStub()
        service.canRunScanResult = true
        let useCase = PermissionGateUseCase(service: service)

        let decision = useCase.canScan(target: URL(fileURLWithPath: "/Users/test"))

        #expect(decision == .allowed)
    }

    @Test
    func canRunProtectedModuleUsesHintOrFallback() {
        let service = PermissionServiceStub()
        service.canRunProtectedResult = false
        let useCase = PermissionGateUseCase(service: service)

        service.permissionHint = "Manual full disk hint"
        let withHint = useCase.canRunProtectedModule(actionName: "Diagnostics")
        #expect(withHint.isAllowed == false)
        #expect(withHint.message == "Manual full disk hint")

        service.permissionHint = nil
        let fallback = useCase.canRunProtectedModule(actionName: "Diagnostics")
        #expect(fallback.isAllowed == false)
        #expect(fallback.message == "Full Disk Access is required for Diagnostics.")
    }

    @Test
    func canModifyForwardsArgumentsAndReturnsFallbackMessage() {
        let service = PermissionServiceStub()
        service.canModifyResult = false
        let useCase = PermissionGateUseCase(service: service)
        let urls = [
            URL(fileURLWithPath: "/Users/test/a"),
            URL(fileURLWithPath: "/Users/test/b")
        ]

        let decision = useCase.canModify(urls: urls, actionName: "Cleanup", requiresFullDisk: true)

        #expect(decision.isAllowed == false)
        #expect(decision.message == "Additional permissions are required for Cleanup.")
        #expect(service.lastModifyCall?.urls == urls)
        #expect(service.lastModifyCall?.actionName == "Cleanup")
        #expect(service.lastModifyCall?.requiresFullDisk == true)
    }
}

@MainActor
private final class PermissionServiceStub: PermissionServicing {
    var permissionHint: String?
    var canRunScanResult = true
    var canRunProtectedResult = true
    var canModifyResult = true
    private(set) var lastModifyCall: (urls: [URL], actionName: String, requiresFullDisk: Bool)?

    func canRunScan(target: URL?) -> Bool {
        canRunScanResult
    }

    func canRunProtectedModule(actionName: String) -> Bool {
        canRunProtectedResult
    }

    func canModify(urls: [URL], actionName: String, requiresFullDisk: Bool) -> Bool {
        lastModifyCall = (urls, actionName, requiresFullDisk)
        return canModifyResult
    }
}
