import Foundation

protocol PrivacyServicing: Sendable {
    func runScan() async -> PrivacyScanReport
    func clean(artifacts: [PrivacyArtifact]) async -> PrivacyCleanReport
}

extension PrivacyService: PrivacyServicing {}

@MainActor
final class PrivacyFeatureController: ObservableObject {
    @Published private(set) var state = PrivacyFeatureState()

    private let privacyService: any PrivacyServicing
    private var context: FeatureContext?

    init(privacyService: any PrivacyServicing) {
        self.privacyService = privacyService
    }

    func attachContext(_ context: FeatureContext) {
        self.context = context
    }

    func applyScanResult(_ report: PrivacyScanReport) {
        state.categories = report.categories.map { category in
            PrivacyCategoryState(id: category.id, category: category, isSelected: false)
        }
        state.cleanReport = nil
    }

    func runScan() {
        guard !state.isScanRunning else { return }
        guard context?.allowProtectedModule("Privacy Scan") ?? false else { return }

        state.isScanRunning = true
        Task { [weak self] in
            guard let self else { return }
            let report = await privacyService.runScan()
            await MainActor.run {
                applyScanResult(report)
                state.isScanRunning = false
                context?.log(
                    category: "privacy",
                    message: "Privacy scan done: categories \(report.categories.count), bytes \(report.totalBytes)"
                )
            }
        }
    }

    func toggleCategory(_ id: String) {
        guard let idx = state.categories.firstIndex(where: { $0.id == id }) else { return }
        state.categories[idx].isSelected.toggle()
    }

    func clearSelection() {
        for index in state.categories.indices {
            state.categories[index].isSelected = false
        }
    }

    func selectRecommended(includeMediumRisk: Bool) {
        for index in state.categories.indices {
            switch state.categories[index].category.risk {
            case .low:
                state.categories[index].isSelected = true
            case .medium:
                state.categories[index].isSelected = includeMediumRisk
            case .high:
                state.categories[index].isSelected = false
            }
        }
    }

    func cleanRecommended(includeMediumRisk: Bool) {
        selectRecommended(includeMediumRisk: includeMediumRisk)
        let actionTitle = includeMediumRisk ? "Quick Clean Recommended" : "Quick Clean Safe"
        cleanSelected(actionTitle: actionTitle)
    }

    func cleanSelected(actionTitle: String = "Clean Selected") {
        let artifacts = state.categories
            .filter(\.isSelected)
            .flatMap(\.category.artifacts)
        guard !artifacts.isEmpty else { return }
        guard context?.allowModify(
            urls: artifacts.map(\.url),
            actionName: "Privacy Cleanup",
            requiresFullDisk: true
        ) ?? false else { return }

        let before = totals(from: state.categories)

        Task { [weak self] in
            guard let self else { return }
            let report = await privacyService.clean(artifacts: artifacts)
            let refreshed = await privacyService.runScan()
            let refreshedCategories = refreshed.categories.map { category in
                PrivacyCategoryState(id: category.id, category: category, isSelected: false)
            }
            let after = totals(from: refreshedCategories)

            await MainActor.run {
                state.cleanReport = report
                state.categories = refreshedCategories
                state.quickActionDelta = QuickActionDeltaReport(
                    module: .privacy,
                    actionTitle: actionTitle,
                    beforeItems: before.items,
                    beforeBytes: before.bytes,
                    afterItems: after.items,
                    afterBytes: after.bytes,
                    moved: report.moved,
                    failed: report.failed,
                    skippedProtected: report.skippedProtected
                )
                context?.log(
                    category: "privacy",
                    message: "Privacy clean moved \(report.moved), failed \(report.failed), skipped \(report.skippedProtected)"
                )
                context?.log(
                    category: "privacy",
                    message: "Privacy clean delta: items \(before.items)->\(after.items), bytes \(before.bytes)->\(after.bytes)"
                )
            }
        }
    }

    private func totals(from categories: [PrivacyCategoryState]) -> (items: Int, bytes: Int64) {
        let items = categories.reduce(0) { partial, category in
            partial + category.category.artifacts.count
        }
        let bytes = categories.reduce(Int64.zero) { partial, category in
            partial + category.category.totalBytes
        }
        return (items, bytes)
    }
}
