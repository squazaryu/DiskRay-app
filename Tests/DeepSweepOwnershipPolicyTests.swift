import Foundation
import Testing
@testable import DRay

@Suite("DeepSweepOwnershipPolicyTests")
struct DeepSweepOwnershipPolicyTests {
    @Test
    func exactIdentityAndReceiptProduceHighConfidence() throws {
        let decision = try #require(DeepSweepOwnershipPolicy.evaluate(
            path: "/Users/test/Library/Caches/com.example.orphan",
            candidateBundleIDs: ["com.example.orphan"],
            installedIdentityBundleIDs: [],
            receiptBundleIDs: ["com.example.orphan"]
        ))

        #expect(decision.bundleID == "com.example.orphan")
        #expect(decision.confidence == .high)
        #expect(decision.allowsAutomaticCleanup)
        #expect(decision.evidence.contains { $0.kind == .exactPathIdentity })
        #expect(decision.evidence.contains { $0.kind == .packageReceipt })
    }

    @Test
    func groupContainerIsAlwaysLowConfidence() throws {
        let decision = try #require(DeepSweepOwnershipPolicy.evaluate(
            path: "/Users/test/Library/Group Containers/group.com.example.shared",
            candidateBundleIDs: ["com.example.shared"],
            installedIdentityBundleIDs: [],
            receiptBundleIDs: ["com.example.shared"]
        ))

        #expect(decision.confidence == .low)
        #expect(!decision.allowsAutomaticCleanup)
        #expect(decision.evidence.contains { $0.kind == .sharedContainer })
    }

    @Test
    func ambiguousIdentifiersRemainReviewOnly() throws {
        let decision = try #require(DeepSweepOwnershipPolicy.evaluate(
            path: "/Users/test/Library/Application Support/com.example.one/com.example.two",
            candidateBundleIDs: ["com.example.one", "com.example.two"],
            installedIdentityBundleIDs: [],
            receiptBundleIDs: ["com.example.one", "com.example.two"]
        ))

        #expect(decision.confidence == .low)
        #expect(!decision.allowsAutomaticCleanup)
        #expect(decision.evidence.contains { $0.kind == .ambiguousIdentifiers })
    }

    @Test
    func installedHelperOrPluginIdentityIsNotAnOrphan() {
        let decision = DeepSweepOwnershipPolicy.evaluate(
            path: "/Users/test/Library/Caches/com.example.demo.helper",
            candidateBundleIDs: ["com.example.demo.helper"],
            installedIdentityBundleIDs: ["com.example.demo", "com.example.demo.helper"],
            receiptBundleIDs: []
        )

        #expect(decision == nil)
    }

    @Test
    func regexOnlyIdentifierIsLowConfidence() throws {
        let decision = try #require(DeepSweepOwnershipPolicy.evaluate(
            path: "/Users/test/Library/Application Support/vendor/state-com.example.orphan-data",
            candidateBundleIDs: ["com.example.orphan-data"],
            installedIdentityBundleIDs: [],
            receiptBundleIDs: []
        ))

        #expect(decision.confidence == .low)
        #expect(!decision.allowsAutomaticCleanup)
        #expect(decision.evidence == [
            UninstallOwnershipEvidence(
                kind: .identifierPattern,
                details: "Path contains identifier com.example.orphan-data."
            )
        ])
    }

    @Test
    func serviceDiscoversInstalledNestedBundleIdentity() async throws {
        let fixture = try DeepSweepFixture()
        let appURL = fixture.root.appendingPathComponent("Demo.app", isDirectory: true)
        let helperURL = appURL.appendingPathComponent(
            "Contents/PlugIns/Helper.appex",
            isDirectory: true
        )
        try createBundle(at: helperURL, identifier: "com.example.demo.helper")
        let cacheRoot = fixture.root.appendingPathComponent("Caches", isDirectory: true)
        let helperCache = cacheRoot.appendingPathComponent(
            "com.example.demo.helper",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: helperCache, withIntermediateDirectories: true)

        let service = AppUninstallerService(
            deepSweepRoots: [cacheRoot],
            receiptBundleIDs: []
        )
        let candidates = await service.deepSweepOrphanRemnants(installedApps: [
            InstalledApp(
                name: "Demo",
                bundleID: "com.example.demo",
                appURL: appURL
            )
        ])

        #expect(candidates.isEmpty)
    }

    private func createBundle(at bundleURL: URL, identifier: String) throws {
        let contents = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleName": "Helper",
            "CFBundlePackageType": "XPC!"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }
}

private final class DeepSweepFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DRayDeepSweepTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}
