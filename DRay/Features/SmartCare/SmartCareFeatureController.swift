import Foundation

@MainActor
final class SmartCareFeatureController: ObservableObject {
    @Published private(set) var state: SmartCareFeatureState

    private let smartCareUseCase: SmartCareUseCase
    private let smartExclusionUseCase: SmartExclusionUseCase
    private var context: FeatureContext?

    let smartAnalyzerOptions: [SmartAnalyzerOption] = [
        .init(key: "user_logs", title: "User Logs", description: "Old files in ~/Library/Logs"),
        .init(key: "user_caches", title: "User Caches", description: "Rebuildable cache files"),
        .init(key: "old_downloads", title: "Old Downloads", description: "Downloads older than 30 days"),
        .init(key: "xcode_derived_data", title: "Xcode DerivedData", description: "Build artifacts"),
        .init(key: "ios_backups", title: "iOS Backups", description: "MobileSync local backups"),
        .init(key: "mail_downloads", title: "Mail Downloads", description: "Saved mail attachments"),
        .init(key: "language_files", title: "Language Files", description: ".lproj localized resources"),
        .init(key: "orphan_preferences", title: "Orphan Preferences", description: "Unused app preference files")
    ]

    init(
        state: SmartCareFeatureState = SmartCareFeatureState(),
        smartCareUseCase: SmartCareUseCase,
        smartExclusionUseCase: SmartExclusionUseCase
    ) {
        self.state = state
        self.smartCareUseCase = smartCareUseCase
        self.smartExclusionUseCase = smartExclusionUseCase
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func loadExclusions() {
        let exclusionState = smartExclusionUseCase.loadState()
        state.exclusions = exclusionState.excludedPaths
        state.excludedAnalyzerKeys = exclusionState.excludedAnalyzerKeys
    }

    func updateMinCleanSizeMB(_ value: Double) {
        state.minCleanSizeMB = max(0, value)
    }

    func runScanSnapshot() async -> SmartScanResult {
        await smartCareUseCase.runScan(
            excludedPrefixes: state.exclusions,
            excludedAnalyzerKeys: state.excludedAnalyzerKeys
        )
    }

    func runSmartScan() {
        guard !state.isScanRunning else { return }
        guard context?.allowProtectedModule("Smart Scan") ?? true else { return }

        state.isScanRunning = true
        context?.log(category: "smartcare", message: "Smart scan started")

        Task { [weak self] in
            guard let self else { return }
            let result = await runScanSnapshot()
            await MainActor.run {
                applySmartScanResult(result)
                state.isScanRunning = false
                context?.log(
                    category: "smartcare",
                    message: "Smart scan done: categories \(result.categories.count), bytes \(result.totalBytes)"
                )
            }
        }
    }

    func toggleSmartCategorySelection(_ id: String) {
        guard let index = state.categories.firstIndex(where: { $0.id == id }) else { return }
        state.categories[index].isSelected.toggle()
    }

    func cleanSelectedSmartCategories() {
        let items = state.categories
            .filter(\.isSelected)
            .flatMap { $0.result.items }
        cleanSmartItems(
            items,
            minSizeBytes: 0,
            actionTitle: "Smart clean"
        )
    }

    func cleanRecommendedSmartCategories() {
        selectRecommendedSmartCategories()
        let items = state.categories
            .filter(\.isSelected)
            .flatMap { $0.result.items }
        cleanSmartItems(
            items,
            minSizeBytes: Int64(state.minCleanSizeMB * 1_048_576),
            actionTitle: "Smart recommended clean"
        )
    }

    func cleanSmartItems(_ items: [CleanupItem]) {
        cleanSmartItems(
            items,
            minSizeBytes: 0,
            actionTitle: "Smart item clean"
        )
    }

    func selectRecommendedSmartCategories() {
        state.categories = smartCareUseCase.applyRecommendations(
            to: state.categories,
            profile: state.profile
        )
    }

    func applySmartProfile(_ profile: SmartCleanProfile) {
        state.profile = profile
        switch profile {
        case .conservative:
            state.minCleanSizeMB = 8
        case .balanced:
            state.minCleanSizeMB = 1
        case .aggressive:
            state.minCleanSizeMB = 0.1
        }
        selectRecommendedSmartCategories()
    }

    func addSmartExclusion(_ path: String) {
        state.exclusions = smartExclusionUseCase.addPath(path, to: state.exclusions)
    }

    func toggleSmartExclusion(_ path: String) {
        state.exclusions = smartExclusionUseCase.togglePath(path, currentPaths: state.exclusions)
    }

    func removeSmartExclusion(_ path: String) {
        state.exclusions = smartExclusionUseCase.removePath(path, from: state.exclusions)
    }

    func toggleSmartAnalyzerExclusion(_ analyzerKey: String) {
        let wasExcluded = state.excludedAnalyzerKeys.contains(analyzerKey)
        state.excludedAnalyzerKeys = smartExclusionUseCase.toggleAnalyzer(
            analyzerKey,
            currentAnalyzerKeys: state.excludedAnalyzerKeys
        )
        guard !analyzerKey.isEmpty else { return }
        context?.log(
            category: "smartcare",
            message: wasExcluded ? "Analyzer enabled: \(analyzerKey)" : "Analyzer excluded: \(analyzerKey)"
        )
    }

    func applySmartScanResult(_ result: SmartScanResult) {
        state.categories = result.categories.map {
            SmartCategoryState(id: $0.key, result: $0, isSelected: $0.isSafeByDefault)
        }
        state.analyzerTelemetry = result.analyzerTelemetry
        selectRecommendedSmartCategories()
    }

    private func cleanSmartItems(
        _ items: [CleanupItem],
        minSizeBytes: Int64,
        actionTitle: String
    ) {
        guard !items.isEmpty else { return }
        guard context?.allowModify(
            urls: items.map(\.url),
            actionName: "Smart Clean",
            requiresFullDisk: false
        ) ?? true else { return }

        context?.log(category: "smartcare", message: "\(actionTitle) started: items \(items.count)")
        Task { [weak self] in
            guard let self else { return }
            let cleanupResult = await smartCareUseCase.clean(items: items, minSizeBytes: minSizeBytes)
            let refreshed = await runScanSnapshot()
            await MainActor.run {
                applySmartScanResult(refreshed)
                context?.log(
                    category: "smartcare",
                    message: "\(actionTitle) moved \(cleanupResult.moved), failed \(cleanupResult.failed)"
                )
            }
        }
    }
}
