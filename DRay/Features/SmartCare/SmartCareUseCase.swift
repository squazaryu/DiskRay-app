import Foundation

protocol SmartCareServicing: Sendable {
    func runSmartScan(
        excludedPrefixes: [String],
        excludedAnalyzerKeys: [String],
        onProgress: (@Sendable (SmartScanProgress) async -> Void)?
    ) async -> SmartScanResult
    func clean(
        items: [CleanupItem],
        minSizeBytes: Int64,
        onProgress: (@Sendable (SmartCleanupProgress) async -> Void)?
    ) async -> CleanupExecutionResult
}

struct SmartCareUseCase {
    let service: any SmartCareServicing

    func runScan(
        excludedPrefixes: [String],
        excludedAnalyzerKeys: [String],
        onProgress: (@Sendable (SmartScanProgress) async -> Void)? = nil
    ) async -> SmartScanResult {
        await service.runSmartScan(
            excludedPrefixes: excludedPrefixes,
            excludedAnalyzerKeys: excludedAnalyzerKeys,
            onProgress: onProgress
        )
    }

    func clean(
        items: [CleanupItem],
        minSizeBytes: Int64,
        onProgress: (@Sendable (SmartCleanupProgress) async -> Void)? = nil
    ) async -> CleanupExecutionResult {
        await service.clean(items: items, minSizeBytes: minSizeBytes, onProgress: onProgress)
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
