import Foundation

protocol SmartCareServicing: Sendable {
    func runSmartScan(
        excludedPrefixes: [String],
        excludedAnalyzerKeys: [String]
    ) async -> SmartScanResult
    func clean(items: [CleanupItem], minSizeBytes: Int64) async -> CleanupExecutionResult
}

struct SmartCareUseCase {
    let service: any SmartCareServicing

    func runScan(
        excludedPrefixes: [String],
        excludedAnalyzerKeys: [String]
    ) async -> SmartScanResult {
        await service.runSmartScan(
            excludedPrefixes: excludedPrefixes,
            excludedAnalyzerKeys: excludedAnalyzerKeys
        )
    }

    func clean(items: [CleanupItem], minSizeBytes: Int64) async -> CleanupExecutionResult {
        await service.clean(items: items, minSizeBytes: minSizeBytes)
    }

    func applyRecommendations(
        to categories: [SmartCategoryState],
        profile: SmartCleanProfile
    ) -> [SmartCategoryState] {
        categories.map { category in
            var updated = category
            let risk = category.result.riskLevel
            let safeByDefault = category.result.isSafeByDefault
            switch profile {
            case .conservative:
                updated.isSelected = safeByDefault && risk == .low
            case .balanced:
                updated.isSelected = safeByDefault && (risk == .low || risk == .medium)
            case .aggressive:
                updated.isSelected = risk != .high
            }
            return updated
        }
    }
}
