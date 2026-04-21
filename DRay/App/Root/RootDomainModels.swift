import Foundation

struct ScanTarget {
    let name: String
    let url: URL
}

struct SearchPreset: Codable, Identifiable {
    let id: UUID
    let name: String
    let query: String
    let minSizeMB: Double
    let pathContains: String
    let ownerContains: String
    let onlyDirectories: Bool
    let onlyFiles: Bool
    let useRegex: Bool
    let depthMin: Int
    let depthMax: Int
    let modifiedWithinDays: Int?
    let nodeTypeRaw: String
    let searchModeRaw: String
    let scopeModeRaw: String
    let scopePath: String?
    let excludeTrash: Bool
    let includeHidden: Bool
    let includePackageContents: Bool

    var nodeType: QueryEngine.SearchNodeType {
        QueryEngine.SearchNodeType(rawValue: nodeTypeRaw) ?? .any
    }

    var searchMode: SearchExecutionMode {
        SearchExecutionMode(rawValue: searchModeRaw) ?? .live
    }

    var scopeMode: SearchScopeMode {
        SearchScopeMode(rawValue: scopeModeRaw) ?? .startupDisk
    }

    init(
        id: UUID,
        name: String,
        query: String,
        minSizeMB: Double,
        pathContains: String,
        ownerContains: String,
        onlyDirectories: Bool,
        onlyFiles: Bool,
        useRegex: Bool,
        depthMin: Int,
        depthMax: Int,
        modifiedWithinDays: Int?,
        nodeType: QueryEngine.SearchNodeType,
        searchMode: SearchExecutionMode,
        scopeMode: SearchScopeMode = .startupDisk,
        scopePath: String? = nil,
        excludeTrash: Bool = true,
        includeHidden: Bool = true,
        includePackageContents: Bool = true
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.minSizeMB = minSizeMB
        self.pathContains = pathContains
        self.ownerContains = ownerContains
        self.onlyDirectories = onlyDirectories
        self.onlyFiles = onlyFiles
        self.useRegex = useRegex
        self.depthMin = depthMin
        self.depthMax = depthMax
        self.modifiedWithinDays = modifiedWithinDays
        self.nodeTypeRaw = nodeType.rawValue
        self.searchModeRaw = searchMode.rawValue
        self.scopeModeRaw = scopeMode.rawValue
        self.scopePath = scopePath
        self.excludeTrash = excludeTrash
        self.includeHidden = includeHidden
        self.includePackageContents = includePackageContents
    }

    enum CodingKeys: String, CodingKey {
        case id, name, query, minSizeMB, pathContains, ownerContains, onlyDirectories, onlyFiles
        case useRegex, depthMin, depthMax, modifiedWithinDays, nodeTypeRaw, searchModeRaw
        case scopeModeRaw, scopePath, excludeTrash, includeHidden, includePackageContents
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        query = try c.decode(String.self, forKey: .query)
        minSizeMB = try c.decode(Double.self, forKey: .minSizeMB)
        pathContains = try c.decode(String.self, forKey: .pathContains)
        ownerContains = try c.decodeIfPresent(String.self, forKey: .ownerContains) ?? ""
        onlyDirectories = try c.decode(Bool.self, forKey: .onlyDirectories)
        onlyFiles = try c.decode(Bool.self, forKey: .onlyFiles)
        useRegex = try c.decodeIfPresent(Bool.self, forKey: .useRegex) ?? false
        depthMin = try c.decodeIfPresent(Int.self, forKey: .depthMin) ?? 0
        depthMax = try c.decodeIfPresent(Int.self, forKey: .depthMax) ?? 128
        modifiedWithinDays = try c.decodeIfPresent(Int.self, forKey: .modifiedWithinDays)
        nodeTypeRaw = try c.decodeIfPresent(String.self, forKey: .nodeTypeRaw) ?? QueryEngine.SearchNodeType.any.rawValue
        searchModeRaw = try c.decodeIfPresent(String.self, forKey: .searchModeRaw) ?? SearchExecutionMode.live.rawValue
        scopeModeRaw = try c.decodeIfPresent(String.self, forKey: .scopeModeRaw) ?? SearchScopeMode.startupDisk.rawValue
        scopePath = try c.decodeIfPresent(String.self, forKey: .scopePath)
        excludeTrash = try c.decodeIfPresent(Bool.self, forKey: .excludeTrash) ?? true
        includeHidden = try c.decodeIfPresent(Bool.self, forKey: .includeHidden) ?? true
        includePackageContents = try c.decodeIfPresent(Bool.self, forKey: .includePackageContents) ?? true
    }
}

struct TrashOperationResult {
    let moved: Int
    let skippedProtected: [String]
    let failed: [String]
}

struct RecentlyDeletedItem: Codable, Identifiable {
    let id: UUID
    let originalPath: String
    let trashedPath: String
    let deletedAt: Date

    var name: String {
        URL(fileURLWithPath: originalPath).lastPathComponent
    }
}

struct PrivacyCategoryState: Identifiable {
    let id: String
    let category: PrivacyCategory
    var isSelected: Bool
}

struct SmartAnalyzerOption: Identifiable, Hashable {
    let key: String
    let title: String
    let description: String

    var id: String { key }
}

struct UnifiedScanSummary {
    let smartCareCategories: Int
    let smartCareBytes: Int64
    let privacyCategories: Int
    let privacyBytes: Int64
    let startupEntries: Int
    let startupBytes: Int64
    let finishedAt: Date
}

struct DiagnosticReport: Codable {
    let generatedAt: Date
    let selectedTargetPath: String
    let unifiedScanSummary: UnifiedScanSnapshot?
    let smartCareCategoryCount: Int
    let privacyCategoryCount: Int
    let startupEntryCount: Int
    let operationLogs: [OperationLogEntry]
}

struct UnifiedScanSnapshot: Codable {
    let smartCareCategories: Int
    let smartCareBytes: Int64
    let privacyCategories: Int
    let privacyBytes: Int64
    let startupEntries: Int
    let startupBytes: Int64
    let finishedAt: Date
}

enum SearchExecutionMode: String, CaseIterable, Identifiable {
    case live

    var id: String { rawValue }
    var title: String { "Live" }
}

enum SearchScopeMode: String, CaseIterable, Identifiable, Codable {
    case startupDisk
    case selectedTarget
    case customPath

    var id: String { rawValue }
}

enum ScanDefaultTarget: String, CaseIterable, Identifiable {
    case startupDisk
    case home
    case lastSelectedFolder

    var id: String { rawValue }
}

enum SmartCleanProfile: String, CaseIterable, Identifiable {
    case conservative
    case balanced
    case aggressive

    var id: String { rawValue }
    var title: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced: return "Balanced"
        case .aggressive: return "Aggressive"
        }
    }
}

enum AppSection: String, Hashable {
    case smartCare
    case clutter
    case uninstaller
    case repair
    case spaceLens
    case search
    case performance
    case privacy
    case recovery
    case settings
}

enum AppRepairStrategy: String, CaseIterable, Identifiable {
    case safeReset
    case deepReset

    var id: String { rawValue }
    var title: String {
        switch self {
        case .safeReset: return "Safe Reset"
        case .deepReset: return "Deep Reset"
        }
    }

    var subtitle: String {
        switch self {
        case .safeReset:
            return "Targets low-risk caches, logs and preferences."
        case .deepReset:
            return "Includes startup helpers and system-level remnants."
        }
    }
}
