import SwiftUI

enum AppAccentColor: String, CaseIterable, Identifiable {
    case blue
    case cyan
    case purple
    case green
    case orange
    case pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .cyan: return .cyan
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        }
    }

    var title: String {
        switch self {
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .purple: return "Purple"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        }
    }
}
