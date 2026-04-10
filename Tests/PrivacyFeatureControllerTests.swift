import Foundation
import Testing
@testable import DRay

@MainActor
struct PrivacyFeatureControllerTests {
    @Test
    func runScanRespectsPermissionGate() async {
        let service = PrivacyServiceStub()
        let controller = PrivacyFeatureController(privacyService: service)

        var blockedMessage: String?
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .blocked("blocked") },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { blockedMessage = $0 },
                addOperationLog: { _, _ in }
            )
        )

        controller.runScan()

        let calls = await service.runScanCalls()
        #expect(calls == 0)
        #expect(blockedMessage == "blocked")
        #expect(controller.state.isScanRunning == false)
    }

    @Test
    func cleanRecommendedBuildsDeltaAfterRefresh() async throws {
        let initial = PrivacyScanReport(
            generatedAt: Date(),
            categories: [
                PrivacyCategory(
                    id: "logs",
                    title: "Logs",
                    details: "Low risk",
                    risk: .low,
                    artifacts: [PrivacyArtifact(url: URL(fileURLWithPath: "/tmp/a.log"), sizeInBytes: 120)]
                ),
                PrivacyCategory(
                    id: "session",
                    title: "Session",
                    details: "High risk",
                    risk: .high,
                    artifacts: [PrivacyArtifact(url: URL(fileURLWithPath: "/tmp/b.dat"), sizeInBytes: 90)]
                )
            ]
        )
        let refreshed = PrivacyScanReport(
            generatedAt: Date(),
            categories: [
                PrivacyCategory(
                    id: "session",
                    title: "Session",
                    details: "High risk",
                    risk: .high,
                    artifacts: [PrivacyArtifact(url: URL(fileURLWithPath: "/tmp/b.dat"), sizeInBytes: 90)]
                )
            ]
        )

        let service = PrivacyServiceStub(
            scanResponses: [refreshed],
            cleanResponse: PrivacyCleanReport(moved: 1, failed: 0, skippedProtected: 0, cleanedBytes: 120)
        )
        let controller = PrivacyFeatureController(privacyService: service)
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, _ in }
            )
        )

        controller.applyScanResult(initial)
        controller.cleanRecommended(includeMediumRisk: false)

        let timeout = Date().addingTimeInterval(2)
        while controller.state.quickActionDelta == nil, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let delta = try #require(controller.state.quickActionDelta)
        let cleanCalls = await service.cleanCalls()
        #expect(cleanCalls == 1)
        #expect(delta.actionTitle == "Quick Clean Safe")
        #expect(delta.beforeItems == 2)
        #expect(delta.afterItems == 1)
    }
}

private actor PrivacyServiceStub: PrivacyServicing {
    private var queuedScanResponses: [PrivacyScanReport]
    private let cleanResult: PrivacyCleanReport

    private var scanCalls = 0
    private var cleanupCalls = 0

    init(
        scanResponses: [PrivacyScanReport] = [],
        cleanResponse: PrivacyCleanReport = PrivacyCleanReport(moved: 0, failed: 0, skippedProtected: 0, cleanedBytes: 0)
    ) {
        self.queuedScanResponses = scanResponses
        self.cleanResult = cleanResponse
    }

    func runScan() async -> PrivacyScanReport {
        scanCalls += 1
        if !queuedScanResponses.isEmpty {
            return queuedScanResponses.removeFirst()
        }
        return PrivacyScanReport(generatedAt: Date(), categories: [])
    }

    func clean(artifacts: [PrivacyArtifact]) async -> PrivacyCleanReport {
        cleanupCalls += 1
        return cleanResult
    }

    func runScanCalls() -> Int {
        scanCalls
    }

    func cleanCalls() -> Int {
        cleanupCalls
    }
}
