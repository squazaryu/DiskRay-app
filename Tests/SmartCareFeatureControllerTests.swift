import Foundation
import Testing
@testable import DRay

@MainActor
struct SmartCareFeatureControllerTests {
    @Test
    func runScanUpdatesStateAndLogs() async throws {
        let expected = SmartScanResult(
            categories: [makeCategory(key: "logs", safe: true, risk: .low)],
            analyzerTelemetry: [CleanupAnalyzerTelemetry(key: "user_logs", title: "User Logs", durationMs: 10, itemCount: 1, totalBytes: 120, skipped: false)]
        )
        let service = SmartCareControllerServiceStub(
            scanResponses: [expected],
            cleanResult: CleanupExecutionResult(moved: 0, failed: 0)
        )
        let controller = makeController(service: service)

        var logs: [String] = []
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { category, message in logs.append("\(category):\(message)") }
            )
        )

        controller.runSmartScan()
        #expect(controller.state.isScanRunning == true)

        let timeout = Date().addingTimeInterval(2)
        while controller.state.isScanRunning, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(controller.state.isScanRunning == false)
        #expect(controller.state.categories.count == 1)
        #expect(controller.state.analyzerTelemetry.count == 1)
        #expect(logs.contains(where: { $0.contains("Smart scan started") }))
        #expect(logs.contains(where: { $0.contains("Smart scan done") }))
    }

    @Test
    func applyProfileAdjustsThresholdAndRecommendations() {
        let service = SmartCareControllerServiceStub(
            scanResponses: [],
            cleanResult: CleanupExecutionResult(moved: 0, failed: 0)
        )
        let controller = makeController(service: service)
        controller.applySmartScanResult(
            SmartScanResult(
                categories: [
                    makeCategory(key: "safe-low", safe: true, risk: .low),
                    makeCategory(key: "safe-medium", safe: true, risk: .medium),
                    makeCategory(key: "safe-high", safe: true, risk: .high),
                    makeCategory(key: "unsafe-low", safe: false, risk: .low)
                ],
                analyzerTelemetry: []
            )
        )

        controller.applySmartProfile(.conservative)
        #expect(controller.state.minCleanSizeMB == 8)
        #expect(selectedCategoryKeys(in: controller.state.categories) == ["safe-low"])

        controller.applySmartProfile(.balanced)
        #expect(controller.state.minCleanSizeMB == 1)
        #expect(selectedCategoryKeys(in: controller.state.categories) == ["safe-low", "safe-medium"])

        controller.applySmartProfile(.aggressive)
        #expect(controller.state.minCleanSizeMB == 0.1)
        #expect(selectedCategoryKeys(in: controller.state.categories) == ["safe-low", "safe-medium", "unsafe-low"])
    }

    @Test
    func exclusionsAndAnalyzerTogglesUpdateState() {
        let service = SmartCareControllerServiceStub(
            scanResponses: [],
            cleanResult: CleanupExecutionResult(moved: 0, failed: 0)
        )
        let controller = makeController(service: service)

        controller.addSmartExclusion("/Users/test/A")
        controller.addSmartExclusion("/Users/test/B")
        #expect(controller.state.exclusions == ["/Users/test/A", "/Users/test/B"])

        controller.toggleSmartExclusion("/Users/test/A")
        #expect(controller.state.exclusions == ["/Users/test/B"])

        controller.removeSmartExclusion("/Users/test/B")
        #expect(controller.state.exclusions.isEmpty)

        controller.toggleSmartAnalyzerExclusion("user_logs")
        #expect(controller.state.excludedAnalyzerKeys == ["user_logs"])
        controller.toggleSmartAnalyzerExclusion("user_logs")
        #expect(controller.state.excludedAnalyzerKeys.isEmpty)
    }

    @Test
    func cleanSelectedUsesManualThresholdAndRefreshesState() async throws {
        let initial = SmartScanResult(
            categories: [makeCategory(key: "logs", safe: true, risk: .low, itemPath: "/tmp/logs.a")],
            analyzerTelemetry: []
        )
        let refreshed = SmartScanResult(
            categories: [makeCategory(key: "logs", safe: true, risk: .low, itemPath: "/tmp/logs.b")],
            analyzerTelemetry: []
        )
        let service = SmartCareControllerServiceStub(
            scanResponses: [refreshed],
            cleanResult: CleanupExecutionResult(moved: 1, failed: 0)
        )
        let controller = makeController(service: service)
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, _ in }
            )
        )
        controller.applySmartScanResult(initial)

        controller.cleanSelectedSmartCategories()

        let timeout = Date().addingTimeInterval(2)
        while await service.cleanCallCount() == 0, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let lastClean = try #require(await service.lastCleanCall())
        #expect(lastClean.minSizeBytes == 0)
        #expect(controller.state.categories.first?.result.items.first?.url.path == "/tmp/logs.b")
    }

    @Test
    func cleanRecommendedUsesProfileThreshold() async throws {
        let initial = SmartScanResult(
            categories: [
                makeCategory(key: "low", safe: true, risk: .low, itemPath: "/tmp/reco-low"),
                makeCategory(key: "high", safe: true, risk: .high, itemPath: "/tmp/reco-high")
            ],
            analyzerTelemetry: []
        )
        let refreshed = SmartScanResult(categories: [], analyzerTelemetry: [])
        let service = SmartCareControllerServiceStub(
            scanResponses: [refreshed],
            cleanResult: CleanupExecutionResult(moved: 1, failed: 0)
        )
        let controller = makeController(service: service)
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, _ in }
            )
        )
        controller.applySmartScanResult(initial)
        controller.applySmartProfile(.conservative)

        controller.cleanRecommendedSmartCategories()

        let timeout = Date().addingTimeInterval(2)
        while await service.cleanCallCount() == 0, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let lastClean = try #require(await service.lastCleanCall())
        #expect(lastClean.minSizeBytes == 8 * 1_048_576)
    }

    private func makeController(service: SmartCareControllerServiceStub) -> SmartCareFeatureController {
        SmartCareFeatureController(
            smartCareUseCase: SmartCareUseCase(service: service),
            smartExclusionUseCase: SmartExclusionUseCase()
        )
    }

    private func selectedCategoryKeys(in categories: [SmartCategoryState]) -> [String] {
        categories.filter(\.isSelected).map(\.id).sorted()
    }

    private func makeCategory(
        key: String,
        safe: Bool,
        risk: CleanupRiskLevel,
        itemPath: String? = nil
    ) -> CleanupCategoryResult {
        CleanupCategoryResult(
            key: key,
            title: key,
            description: key,
            isSafeByDefault: safe,
            riskLevel: risk,
            recommendationReason: "test",
            items: [
                CleanupItem(
                    url: URL(fileURLWithPath: itemPath ?? "/tmp/\(key)"),
                    sizeInBytes: 512
                )
            ]
        )
    }
}

private actor SmartCareControllerServiceStub: SmartCareServicing {
    private var queuedScanResponses: [SmartScanResult]
    private let cleanResult: CleanupExecutionResult
    private(set) var cleanCalls: [(items: [CleanupItem], minSizeBytes: Int64)] = []

    init(scanResponses: [SmartScanResult], cleanResult: CleanupExecutionResult) {
        self.queuedScanResponses = scanResponses
        self.cleanResult = cleanResult
    }

    func runSmartScan(excludedPrefixes: [String], excludedAnalyzerKeys: [String]) async -> SmartScanResult {
        if !queuedScanResponses.isEmpty {
            return queuedScanResponses.removeFirst()
        }
        return SmartScanResult(categories: [], analyzerTelemetry: [])
    }

    func clean(items: [CleanupItem], minSizeBytes: Int64) async -> CleanupExecutionResult {
        cleanCalls.append((items, minSizeBytes))
        return cleanResult
    }

    func cleanCallCount() -> Int {
        cleanCalls.count
    }

    func lastCleanCall() -> (items: [CleanupItem], minSizeBytes: Int64)? {
        cleanCalls.last
    }
}
