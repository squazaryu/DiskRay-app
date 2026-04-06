import Foundation
import Testing
@testable import DRay

struct SmartCareUseCaseTests {
    @Test
    func runScanDelegatesToServiceWithGivenFilters() async {
        let expected = SmartScanResult(
            categories: [makeCategory(key: "logs", safe: true, risk: .low)],
            analyzerTelemetry: []
        )
        let service = SmartCareServiceStub(scanResult: expected, cleanResult: CleanupExecutionResult(moved: 0, failed: 0))
        let useCase = SmartCareUseCase(service: service)

        let result = await useCase.runScan(
            excludedPrefixes: ["/Users/test/ignore"],
            excludedAnalyzerKeys: ["user_logs"]
        )

        #expect(result.categories.count == 1)
        #expect(result.categories.first?.key == "logs")

        let call = await service.lastRunCall()
        #expect(call?.excludedPrefixes == ["/Users/test/ignore"])
        #expect(call?.excludedAnalyzerKeys == ["user_logs"])
    }

    @Test
    func cleanDelegatesToServiceWithThreshold() async {
        let expected = CleanupExecutionResult(moved: 2, failed: 1)
        let service = SmartCareServiceStub(
            scanResult: SmartScanResult(categories: [], analyzerTelemetry: []),
            cleanResult: expected
        )
        let useCase = SmartCareUseCase(service: service)
        let items = [
            CleanupItem(url: URL(fileURLWithPath: "/tmp/a"), sizeInBytes: 2_000_000),
            CleanupItem(url: URL(fileURLWithPath: "/tmp/b"), sizeInBytes: 8_000_000)
        ]

        let result = await useCase.clean(items: items, minSizeBytes: 3_000_000)

        #expect(result.moved == 2)
        #expect(result.failed == 1)

        let call = await service.lastCleanCall()
        #expect(call?.items.count == 2)
        #expect(call?.minSizeBytes == 3_000_000)
    }

    @Test
    func recommendationSelectionFollowsProfileRules() {
        let useCase = SmartCareUseCase(service: SmartScanService())
        let categories = [
            makeCategory(key: "safe-low", safe: true, risk: .low),
            makeCategory(key: "safe-medium", safe: true, risk: .medium),
            makeCategory(key: "safe-high", safe: true, risk: .high),
            makeCategory(key: "unsafe-low", safe: false, risk: .low)
        ].map { SmartCategoryState(id: $0.key, result: $0, isSelected: false) }

        let conservative = useCase.applyRecommendations(to: categories, profile: .conservative)
        #expect(selectedKeys(in: conservative) == ["safe-low"])

        let balanced = useCase.applyRecommendations(to: categories, profile: .balanced)
        #expect(selectedKeys(in: balanced) == ["safe-low", "safe-medium"])

        let aggressive = useCase.applyRecommendations(to: categories, profile: .aggressive)
        #expect(selectedKeys(in: aggressive) == ["safe-low", "safe-medium", "unsafe-low"])
    }

    private func selectedKeys(in categories: [SmartCategoryState]) -> [String] {
        categories.filter(\.isSelected).map(\.id).sorted()
    }

    private func makeCategory(key: String, safe: Bool, risk: CleanupRiskLevel) -> CleanupCategoryResult {
        CleanupCategoryResult(
            key: key,
            title: key,
            description: key,
            isSafeByDefault: safe,
            riskLevel: risk,
            recommendationReason: "test",
            items: [CleanupItem(url: URL(fileURLWithPath: "/tmp/\(key)"), sizeInBytes: 1)]
        )
    }
}

private actor SmartCareServiceStub: SmartCareServicing {
    private(set) var runCalls: [(excludedPrefixes: [String], excludedAnalyzerKeys: [String])] = []
    private(set) var cleanCalls: [(items: [CleanupItem], minSizeBytes: Int64)] = []
    private let scanResult: SmartScanResult
    private let cleanResult: CleanupExecutionResult

    init(scanResult: SmartScanResult, cleanResult: CleanupExecutionResult) {
        self.scanResult = scanResult
        self.cleanResult = cleanResult
    }

    func runSmartScan(excludedPrefixes: [String], excludedAnalyzerKeys: [String]) async -> SmartScanResult {
        runCalls.append((excludedPrefixes, excludedAnalyzerKeys))
        return scanResult
    }

    func clean(items: [CleanupItem], minSizeBytes: Int64) async -> CleanupExecutionResult {
        cleanCalls.append((items, minSizeBytes))
        return cleanResult
    }

    func lastRunCall() -> (excludedPrefixes: [String], excludedAnalyzerKeys: [String])? {
        runCalls.last
    }

    func lastCleanCall() -> (items: [CleanupItem], minSizeBytes: Int64)? {
        cleanCalls.last
    }
}
