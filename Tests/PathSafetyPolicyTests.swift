import Foundation
import Testing
@testable import DRay

struct PathSafetyPolicyTests {
    @Test
    func classifiesProtectedSystemPathsAsManualOnly() {
        let system = PathSafetyPolicy.assess("/System")
        let usrBin = PathSafetyPolicy.assess("/usr/bin")

        #expect(system.classification == .systemProtected)
        #expect(system.disposition == .manualOnly)
        #expect(usrBin.classification == .systemProtected)
        #expect(usrBin.disposition == .manualOnly)
    }

    @Test
    func classifiesApplicationBundlesAsAdminCapableWithHighRiskForceGate() {
        let assessment = PathSafetyPolicy.assess("/Applications/Test.app")

        #expect(assessment.classification == .appBundle)
        #expect(assessment.adminTrashAllowed)
        #expect(assessment.forceRemoveAllowedOnlyWithHighRiskMode)
        #expect(!assessment.manualOnly)
    }

    @Test
    func classifiesUserCachesAsSafeCleanupCandidates() {
        let cacheURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/com.example.demo/cache.db")
        let assessment = PathSafetyPolicy.assess(cacheURL.path)

        #expect(assessment.classification == .cacheSafe)
        #expect(assessment.standardTrashAllowed)
        #expect(!assessment.shouldSkipForSafeCleanup)
    }

    @Test
    func classifiesUserPreferencesAsManualOnly() {
        let dockPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        let appPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.example.demo.plist")

        let dockAssessment = PathSafetyPolicy.assess(dockPlist.path)
        let appAssessment = PathSafetyPolicy.assess(appPlist.path)

        #expect(dockAssessment.classification == .userData)
        #expect(dockAssessment.disposition == .manualOnly)
        #expect(dockAssessment.shouldSkipForSafeCleanup)
        #expect(appAssessment.classification == .userData)
        #expect(appAssessment.disposition == .manualOnly)
        #expect(appAssessment.shouldSkipForSafeCleanup)
    }

    @Test
    func classifiesSystemDaemonAndHelperPathsAsAdminSensitive() {
        let daemon = PathSafetyPolicy.assess("/Library/LaunchDaemons/com.example.demo.plist")
        let helper = PathSafetyPolicy.assess("/Library/PrivilegedHelperTools/com.example.demo")

        #expect(daemon.classification == .adminSensitive)
        #expect(daemon.adminTrashAllowed)
        #expect(daemon.shouldSkipForSafeCleanup)
        #expect(helper.classification == .adminSensitive)
        #expect(helper.adminTrashAllowed)
        #expect(helper.shouldSkipForSafeCleanup)
    }
}
