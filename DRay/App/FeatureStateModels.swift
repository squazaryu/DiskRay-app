import Foundation

struct SmartCategoryState: Identifiable {
    let id: String
    let result: CleanupCategoryResult
    var isSelected: Bool
}

struct SearchFeatureState {
    var query = ""
    var minSizeMB: Double = 0
    var pathContains = ""
    var ownerContains = ""
    var onlyDirectories = false
    var onlyFiles = false
    var useRegex = false
    var depthMin = 0
    var depthMax = 64
    var modifiedWithinDays = 0
    var nodeType: QueryEngine.SearchNodeType = .any
    var mode: SearchExecutionMode = .live
    var scopeMode: SearchScopeMode = .startupDisk
    var customScopePath = "/"
    var excludeTrash = true
    var includeHidden = true
    var includePackageContents = true
    var isLiveRunning = false
    var liveResults: [FileNode] = []
    var presets: [SearchPreset] = []

    var results: [FileNode] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return liveResults
    }
}

struct SmartCareFeatureState {
    var categories: [SmartCategoryState] = []
    var isScanRunning = false
    var exclusions: [String] = []
    var excludedAnalyzerKeys: [String] = []
    var analyzerTelemetry: [CleanupAnalyzerTelemetry] = []
    var minCleanSizeMB: Double = 1
    var profile: SmartCleanProfile = .balanced
}

struct PerformanceFeatureState {
    var report: PerformanceReport?
    var isScanRunning = false
    var startupCleanupReport: StartupCleanupReport?
    var activeLoadReliefAdjustments = 0
    var quickActionDelta: QuickActionDeltaReport?
}

struct PrivacyFeatureState {
    var categories: [PrivacyCategoryState] = []
    var isScanRunning = false
    var cleanReport: PrivacyCleanReport?
    var quickActionDelta: QuickActionDeltaReport?
}

struct RecoveryFeatureState {
    var recentlyDeleted: [RecentlyDeletedItem] = []
    var quickActionRollbackSessions: [QuickActionRollbackSession] = []
}

struct UninstallerFeatureState {
    var installedApps: [InstalledApp] = []
    var remnants: [AppRemnant] = []
    var isLoading = false
    var uninstallReport: UninstallValidationReport?
    var verifyReport: UninstallVerifyReport?
    var isVerifyRunning = false
    var sessions: [UninstallSession] = []
}

struct RepairFeatureState {
    var artifacts: [AppRemnant] = []
    var isLoading = false
    var report: UninstallValidationReport?
    var sessions: [UninstallSession] = []
}
