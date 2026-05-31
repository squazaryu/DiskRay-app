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
        #expect(!PathSafetyPolicy.isProtected(appPlist.path))
        #expect(PathSafetyPolicy.isUserPreferenceStatePath(appPlist.path))
    }

    @Test
    func defaultCleanupSkipsSystemAndUserSettingsState() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let protectedDefaults = [
            home.appendingPathComponent("Library/Preferences/com.apple.dock.plist").path,
            home.appendingPathComponent("Library/LaunchAgents/com.apple.some-agent.plist").path,
            home.appendingPathComponent("Library/Keychains/login.keychain-db").path,
            home.appendingPathComponent("Library/Messages/chat.db").path,
            home.appendingPathComponent("Library/Application Support/Dock/desktoppicture.db").path,
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db").path,
            home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/History").path,
            home.appendingPathComponent("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments").path,
            home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail.plist").path,
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/report.pdf").path,
            home.appendingPathComponent("Library/Autosave Information/Unsaved Document.pages").path,
            home.appendingPathComponent("Library/Safari/Bookmarks.plist").path,
            home.appendingPathComponent("Library/WebKit/WebsiteData/Default").path,
            home.appendingPathComponent("Library/UserNotifications/Store.db").path,
            home.appendingPathComponent("Library/Application Support/MobileSync/Backup/device/Info.plist").path,
            "/Library/LaunchDaemons/com.example.daemon.plist",
            "/Library/Preferences/com.example.system.plist"
        ]

        for path in protectedDefaults {
            #expect(PathSafetyPolicy.shouldSkipForDefaultCleanup(path))
        }

        let allowedDefaults = [
            home.appendingPathComponent("Library/Caches/com.example.cache/payload.db").path,
            home.appendingPathComponent("Library/Logs/com.example.app/log.txt").path,
            home.appendingPathComponent("Downloads/old-installer.dmg").path
        ]

        for path in allowedDefaults {
            #expect(!PathSafetyPolicy.shouldSkipForDefaultCleanup(path))
        }
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
