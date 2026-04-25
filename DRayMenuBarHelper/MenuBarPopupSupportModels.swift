import SwiftUI

struct HealthIssue: Identifiable {
    let id = UUID()
    let title: String
    let details: String
    let severity: HealthIssueSeverity
}

struct ConsumerRow: Identifiable {
    let id: String
    let name: String
    let cpuText: String
    let memoryText: String
    let batteryText: String
}

enum ReliefAction {
    case cpu
    case memory
}

enum HealthIssueSeverity {
    case info
    case warning
    case critical

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
