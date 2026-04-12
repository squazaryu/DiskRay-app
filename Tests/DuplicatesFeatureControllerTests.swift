import Foundation
import Testing
@testable import DRay

@MainActor
struct DuplicatesFeatureControllerTests {
    @Test
    func scanUpdatesStateAndLogs() async throws {
        let group = makeGroup(
            signature: "group-a",
            files: [
                DuplicateFile(url: URL(fileURLWithPath: "/tmp/a"), sizeInBytes: 1_024, modifiedAt: nil),
                DuplicateFile(url: URL(fileURLWithPath: "/tmp/b"), sizeInBytes: 1_024, modifiedAt: nil)
            ],
            size: 1_024
        )
        let finder = ImmediateDuplicateFinderStub(groups: [group])
        let controller = DuplicatesFeatureController(
            duplicateFinderService: finder,
            safeFileOperations: SafeFileOperationService()
        )

        var logs: [String] = []
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, message in logs.append(message) }
            )
        )

        controller.scanDuplicatesInSelectedTarget(URL(fileURLWithPath: "/tmp"))
        #expect(controller.state.isScanRunning == true)

        let timeout = Date().addingTimeInterval(2)
        while controller.state.isScanRunning, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(controller.state.isScanRunning == false)
        #expect(controller.state.groups.count == 1)
        #expect(controller.state.progress.phase == "Completed")
        #expect(logs.contains(where: { $0.contains("Duplicate scan started") }))
        #expect(logs.contains(where: { $0.contains("Duplicate scan completed") }))
    }

    @Test
    func cancelFlowMarksStateAndLogs() async throws {
        let finder = DelayedDuplicateFinderStub(delayNanoseconds: 1_000_000_000)
        let controller = DuplicatesFeatureController(
            duplicateFinderService: finder,
            safeFileOperations: SafeFileOperationService()
        )

        var logs: [String] = []
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .allowed },
                presentPermissionBlock: { _ in },
                addOperationLog: { _, message in logs.append(message) }
            )
        )

        controller.scanDuplicatesInSelectedTarget(URL(fileURLWithPath: "/tmp"))
        try await Task.sleep(nanoseconds: 100_000_000)
        controller.cancelDuplicateScan()

        #expect(controller.state.isScanRunning == false)
        #expect(controller.state.progress.phase == "Canceled")
        #expect(logs.contains(where: { $0.contains("Duplicate scan canceled") }))
    }

    @Test
    func cleanupRemovesMovedPathsFromGroups() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = tempDir.appendingPathComponent("a.txt")
        let second = tempDir.appendingPathComponent("b.txt")
        try "same".write(to: first, atomically: true, encoding: .utf8)
        try "same".write(to: second, atomically: true, encoding: .utf8)

        let group = makeGroup(
            signature: "group-temp",
            files: [
                DuplicateFile(url: first, sizeInBytes: 4, modifiedAt: nil),
                DuplicateFile(url: second, sizeInBytes: 4, modifiedAt: nil)
            ],
            size: 4
        )
        let finder = ImmediateDuplicateFinderStub(groups: [group])
        let controller = DuplicatesFeatureController(
            duplicateFinderService: finder,
            safeFileOperations: SafeFileOperationService()
        )

        controller.scanDuplicatesInSelectedTarget(tempDir)
        let timeout = Date().addingTimeInterval(2)
        while controller.state.isScanRunning, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        var movedFromOutcome = 0
        var didTriggerCleanup = false
        let result = controller.moveDuplicatePathsToTrash(
            [first.path],
            onMovedItems: { moved in movedFromOutcome = moved.count },
            onSuccessfulCleanup: { didTriggerCleanup = true }
        )

        #expect(result.moved == 1)
        #expect(movedFromOutcome == 1)
        #expect(didTriggerCleanup == true)
        #expect(controller.state.groups.isEmpty)
    }

    @Test
    func missingPathsReportedAsFailures() throws {
        let controller = DuplicatesFeatureController(
            duplicateFinderService: ImmediateDuplicateFinderStub(groups: []),
            safeFileOperations: SafeFileOperationService()
        )

        let missingPath = "/tmp/dray-duplicates-missing-\(UUID().uuidString)"
        let result = controller.moveDuplicatePathsToTrash([missingPath])

        #expect(result.moved == 0)
        #expect(result.failed.contains(missingPath))
    }

    @Test
    func permissionAndProtectedPathsHandled() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("permission-test.txt")
        try "deny".write(to: fileURL, atomically: true, encoding: .utf8)

        let controller = DuplicatesFeatureController(
            duplicateFinderService: ImmediateDuplicateFinderStub(groups: []),
            safeFileOperations: SafeFileOperationService()
        )

        var blockedMessage: String?
        controller.attachContext(
            FeatureContext(
                canRunProtectedModule: { _ in .allowed },
                canModify: { _, _, _ in .blocked("blocked-by-test") },
                presentPermissionBlock: { blockedMessage = $0 },
                addOperationLog: { _, _ in }
            )
        )

        let permissionResult = controller.moveDuplicatePathsToTrash([fileURL.path])
        #expect(permissionResult.moved == 0)
        #expect(permissionResult.failed.contains(fileURL.path))
        #expect(blockedMessage == "blocked-by-test")

        let protectedPath = "/System/Library"
        let protectedResult = controller.moveDuplicatePathsToTrash([protectedPath])
        #expect(protectedResult.moved == 0)
        #expect(protectedResult.skippedProtected.contains(protectedPath))
    }

    private func makeGroup(
        signature: String,
        files: [DuplicateFile],
        size: Int64
    ) -> DuplicateGroup {
        DuplicateGroup(signature: signature, files: files, sizeInBytes: size)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-duplicates-controller-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

private actor ImmediateDuplicateFinderStub: DuplicateFinding {
    private let groups: [DuplicateGroup]

    init(groups: [DuplicateGroup]) {
        self.groups = groups
    }

    func scan(
        roots: [URL],
        minFileSizeBytes: Int64,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) async -> [DuplicateGroup] {
        onProgress?(
            DuplicateScanProgress(
                phase: "Scanning",
                currentPath: roots.first?.path ?? "/",
                visitedFiles: 12,
                candidateGroups: groups.count
            )
        )
        return groups
    }
}

private actor DelayedDuplicateFinderStub: DuplicateFinding {
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func scan(
        roots: [URL],
        minFileSizeBytes: Int64,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) async -> [DuplicateGroup] {
        onProgress?(
            DuplicateScanProgress(
                phase: "Scanning",
                currentPath: roots.first?.path ?? "/",
                visitedFiles: 1,
                candidateGroups: 0
            )
        )
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        if Task.isCancelled {
            return []
        }
        return []
    }
}
