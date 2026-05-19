import CoreGraphics
import Testing
@testable import DRay

struct AppInterfaceDensityTests {
    @Test
    func adaptiveKeepsComfortableLayoutForNormalWindows() {
        #expect(AppInterfaceDensity.adaptive.resolved(for: CGSize(width: 1280, height: 800)) == .comfortable)
        #expect(AppInterfaceDensity.adaptive.resolved(for: CGSize(width: 1440, height: 760)) == .comfortable)
    }

    @Test
    func adaptiveUsesCompactOnlyForSmallWindows() {
        #expect(AppInterfaceDensity.adaptive.resolved(for: CGSize(width: 1080, height: 800)) == .compact)
        #expect(AppInterfaceDensity.adaptive.resolved(for: CGSize(width: 1280, height: 680)) == .compact)
    }
}
