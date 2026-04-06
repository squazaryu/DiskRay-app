import Foundation
import Testing
@testable import DRay

struct SafeFileOperationServiceTests {
    @Test
    func systemPathProtectionDetectsProtectedAndUserPaths() {
        #expect(SystemPathProtection.isProtected("/"))
        #expect(SystemPathProtection.isProtected("/System/Library"))
        #expect(SystemPathProtection.isProtected("/usr/libexec"))
        #expect(!SystemPathProtection.isProtected("/Users/test/Documents"))
        #expect(!SystemPathProtection.isProtected("/Applications/MyApp.app"))
    }

    @Test
    func uniqueRestoreURLReturnsOriginalWhenFree() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = SafeFileOperationService()
        let desired = tempDir.appendingPathComponent("report.txt")
        let candidate = service.uniqueRestoreURL(for: desired)

        #expect(candidate.path == desired.path)
    }

    @Test
    func uniqueRestoreURLAddsNumericSuffixWhenNameAlreadyExists() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let desired = tempDir.appendingPathComponent("report.txt")
        try Data("a".utf8).write(to: desired)
        try Data("b".utf8).write(to: tempDir.appendingPathComponent("report (1).txt"))

        let service = SafeFileOperationService()
        let candidate = service.uniqueRestoreURL(for: desired)

        #expect(candidate.lastPathComponent == "report (2).txt")
    }

    @Test
    func restoreUsesUniqueDestinationWhenOriginalPathAlreadyExists() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let original = tempDir.appendingPathComponent("note.txt")
        let trashed = tempDir.appendingPathComponent("note_trashed.txt")
        try Data("existing".utf8).write(to: original)
        try Data("restored".utf8).write(to: trashed)

        let service = SafeFileOperationService()
        let outcome = service.restore([
            SafeRestoreRequest(originalPath: original.path, trashedPath: trashed.path)
        ])

        #expect(outcome.restored.count == 1)
        #expect(outcome.failures.isEmpty)
        #expect(outcome.restored[0].restoredPath == tempDir.appendingPathComponent("note (1).txt").path)

        let restoredData = try Data(contentsOf: URL(fileURLWithPath: outcome.restored[0].restoredPath))
        #expect(String(decoding: restoredData, as: UTF8.self) == "restored")
    }

    @Test
    func moveToTrashSkipsProtectedPathWithoutAttemptingDelete() {
        let service = SafeFileOperationService()
        let protectedNode = FileNode(
            url: URL(fileURLWithPath: "/System"),
            name: "System",
            isDirectory: true,
            sizeInBytes: 0,
            children: []
        )

        let outcome = service.moveToTrash(
            nodes: [protectedNode],
            actionName: "Move to Trash",
            canModify: { _, _ in true },
            permissionHint: { nil }
        )

        #expect(outcome.skippedProtected == ["/System"])
        #expect(outcome.moved.isEmpty)
        #expect(outcome.failures.isEmpty)
    }

    @Test
    func moveToTrashReportsPermissionFailure() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sample.txt")
        try Data("payload".utf8).write(to: fileURL)
        let node = FileNode(
            url: fileURL,
            name: "sample.txt",
            isDirectory: false,
            sizeInBytes: 7,
            children: []
        )

        let service = SafeFileOperationService()
        let outcome = service.moveToTrash(
            nodes: [node],
            actionName: "Move to Trash",
            canModify: { _, _ in false },
            permissionHint: { "Permission denied by test" }
        )

        #expect(outcome.moved.isEmpty)
        #expect(outcome.failures.count == 1)
        #expect(outcome.failures[0].path == fileURL.path)
        #expect(outcome.failures[0].isPermission)
        #expect(outcome.blockedPermissionHint == "Permission denied by test")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let url = root.appendingPathComponent("dray-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
