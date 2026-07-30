import Foundation
import Testing
@testable import DRay

@Suite("UninstallRemainingIssueClassificationTests")
struct UninstallRemainingIssueClassificationTests {
    @Test
    func legacyPreferenceRecordMigratesAwayFromSIPTCCCategory() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.example.demo.plist")
            .path
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "path": "\(path)",
          "sizeInBytes": 1024,
          "reason": "Skipped: system-protected path (SIP/TCC).",
          "risk": "low"
        }
        """

        let record = try JSONDecoder().decode(
            UninstallRemainingIssueRecord.self,
            from: Data(json.utf8)
        )

        #expect(record.category == .preference)
        #expect(record.remediation == .reviewPreferenceAndClean)
    }

    @Test
    func daemonAndHelperPathsUseDistinctTypedCategories() {
        let daemon = UninstallRemainingIssueRecord(
            path: "/Library/LaunchDaemons/com.example.helper.plist",
            sizeInBytes: 10,
            reason: "Failed",
            risk: .high
        )
        let helper = UninstallRemainingIssueRecord(
            path: "/Library/PrivilegedHelperTools/com.example.helper",
            sizeInBytes: 10,
            reason: "Failed",
            risk: .high
        )

        #expect(daemon.category == .launchDaemon)
        #expect(helper.category == .privilegedHelper)
        #expect(daemon.remediation == .unloadAndRetryWithAdministrator)
        #expect(helper.remediation == .unloadAndRetryWithAdministrator)
    }

    @Test
    func typedCategoryAndRemediationRoundTrip() throws {
        let original = UninstallRemainingIssueRecord(
            path: "/Applications/Demo.app",
            sizeInBytes: 42,
            reason: "Admin Trash failed.",
            risk: .high,
            category: .appBundle,
            remediation: .retryWithAdministrator
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UninstallRemainingIssueRecord.self, from: data)

        #expect(decoded == original)
        #expect(decoded.category == .appBundle)
        #expect(decoded.remediation == .retryWithAdministrator)
    }

    @Test
    func permissionFailureUsesPermissionCategory() {
        let issue = UninstallVerifyIssue(
            url: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/com.example.demo/cache.db"),
            sizeInBytes: 5,
            reason: "Operation not permitted",
            risk: .low,
            failureCategory: .permissionDenied,
            itemType: .remnant
        )

        #expect(issue.category == .permissionDenied)
        #expect(issue.remediation == .grantFullDiskAccessAndRetry)
    }

    @Test
    func protectedSystemPathUsesSystemProtectedCategory() {
        let issue = UninstallRemainingIssueRecord(
            path: "/System/Library/CoreServices/Finder.app",
            sizeInBytes: 1,
            reason: "Skipped: protected by SIP/TCC.",
            risk: .high
        )

        #expect(issue.category == .systemProtected)
        #expect(issue.remediation == .keepExcludedOrHandleOutsideDRay)
    }
}
