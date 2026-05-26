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
    var validationMessage: String?
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
    var currentScanStartedAt: Date?
    var currentScanProgress: SmartScanProgress?
    var lastScanReport: SmartCareScanReport?
    var isCleanupRunning = false
    var currentCleanupStartedAt: Date?
    var currentCleanupProgress: SmartCleanupProgress?
    var lastCleanupReport: SmartCareCleanupReport?
    var exclusions: [String] = []
    var excludedAnalyzerKeys: [String] = []
    var analyzerTelemetry: [CleanupAnalyzerTelemetry] = []
    var minCleanSizeMB: Double = 1
    var profile: SmartCleanProfile = .balanced
}

struct SmartCareScanReport {
    let finishedAt: Date
    let durationMs: Int
    let categories: Int
    let items: Int
    let totalBytes: Int64
    let deltaBytes: Int64
    let deltaItems: Int
}

struct SmartCareCleanupReport {
    let finishedAt: Date
    let durationMs: Int
    let total: Int
    let moved: Int
    let failed: Int
}

struct DuplicatesFeatureState {
    var groups: [DuplicateGroup] = []
    var isScanRunning = false
    var progress = DuplicateScanProgress(
        phase: "Idle",
        currentPath: "",
        visitedFiles: 0,
        candidateGroups: 0
    )
    var minSizeMB: Double = 10
}

struct PerformanceFeatureState {
    var report: PerformanceReport?
    var isScanRunning = false
    var startupCleanupReport: StartupCleanupReport?
    var activeLoadReliefAdjustments = 0
    var quickActionDelta: QuickActionDeltaReport?
    var batteryEnergyReport: BatteryEnergyReport?
    var isBatteryEnergyLoading = false
    var energyModeSettings: MacEnergyModeSettings?
    var isEnergyModeLoading = false
    var isEnergyModeApplying = false
    var energyModeMessage: String?
    var networkSpeedTestResult: NetworkSpeedTestResult?
    var isNetworkSpeedTestRunning = false
}

struct NetworkSpeedTestResult: Sendable {
    let measuredAt: Date
    let interfaceName: String?
    let downlinkMbps: Double?
    let uplinkMbps: Double?
    let responsivenessMs: Double?
    let baseRTTMs: Double?
    let errorMessage: String?

    var isSuccess: Bool {
        errorMessage == nil
    }
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
    var uninstallMode: UninstallMode = .standard
    var experimentalElevatedDeletionEnabled = false
    var installedApps: [InstalledApp] = []
    var remnants: [AppRemnant] = []
    var isLoading = false
    var uninstallReport: UninstallValidationReport?
    var verifyReport: UninstallVerifyReport?
    var isVerifyRunning = false
    var sessions: [UninstallSession] = []
    var remainingRecords: [UninstallRemainingRecord] = []
    var removedAppCandidates: [UninstallRemovedAppCandidate] = []
}

struct RepairFeatureState {
    var artifacts: [AppRemnant] = []
    var isLoading = false
    var report: UninstallValidationReport?
    var sessions: [UninstallSession] = []
}
