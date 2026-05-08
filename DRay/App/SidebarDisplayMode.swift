import SwiftUI

enum SidebarDisplayMode: String, CaseIterable, Identifiable {
    case adaptive
    case expanded
    case collapsed

    var id: String { rawValue }

    func resolved(for size: CGSize) -> SidebarDisplayMode {
        switch self {
        case .adaptive:
            return size.width >= 1280 ? .expanded : .collapsed
        case .expanded:
            return .expanded
        case .collapsed:
            return .collapsed
        }
    }
}
