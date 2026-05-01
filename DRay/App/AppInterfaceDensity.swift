import SwiftUI

enum AppInterfaceDensity: String, CaseIterable, Identifiable {
    case adaptive
    case comfortable
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: return "Adaptive"
        case .comfortable: return "Comfortable"
        case .compact: return "Compact"
        }
    }

    func resolved(for size: CGSize) -> AppInterfaceDensity {
        guard self == .adaptive else { return self }
        return size.width < 1320 || size.height < 860 ? .compact : .comfortable
    }
}
