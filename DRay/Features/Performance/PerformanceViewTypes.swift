import SwiftUI

enum ReliefAction {
    case cpu
    case memory
}

enum PerformanceWorkspaceTab: Hashable {
    case overview
    case systemLoad
    case batteryEnergy
    case startup
    case network
}

struct LiveConsumerRow: Identifiable {
    let id: String
    let displayName: String
    var cpuPercent: Double
    var memoryMB: Double
    var batteryImpactScore: Double
}

struct NetworkHistoryPoint: Identifiable {
    let id = UUID()
    let measuredAt: Date
    let downMbps: Double
    let upMbps: Double
    let responsivenessMs: Double
}

enum NetworkDataRepresentation: String, CaseIterable, Identifiable {
    case bits
    case bytes
    case packets

    var id: String { rawValue }
}

enum NetworkWorkspaceSubscreen: String, CaseIterable, Identifiable {
    case overview
    case liveMap
    case tools

    var id: String { rawValue }
}

enum NetworkPrivacyCapability {
    case publicIP
    case remoteEndpoints
}

struct NetworkRatePoint: Identifiable {
    let id = UUID()
    let measuredAt: Date
    let incoming: Double
    let outgoing: Double
}

enum StartupImpact {
    case low
    case review
    case high

    var title: String {
        switch self {
        case .low: return "Low"
        case .review: return "Review"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .review: return .orange
        case .high: return .red
        }
    }
}
