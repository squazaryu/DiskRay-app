import Foundation

struct SafeTrashMove: Sendable {
    let originalPath: String
    let trashedPath: String
}

struct SafeTrashFailure: Sendable {
    let path: String
    let reason: String
    let isPermission: Bool
}

struct SafeTrashOutcome: Sendable {
    let moved: [SafeTrashMove]
    let skippedProtected: [String]
    let failures: [SafeTrashFailure]
    let blockedPermissionHint: String?
}

struct SafeRestoreRequest: Sendable {
    let originalPath: String
    let trashedPath: String
}

struct SafeRestoreMove: Sendable {
    let originalPath: String
    let restoredPath: String
    let trashedPath: String
}

struct SafeRestoreFailure: Sendable {
    let originalPath: String
    let trashedPath: String
    let reason: String
}

struct SafeRestoreOutcome: Sendable {
    let restored: [SafeRestoreMove]
    let failures: [SafeRestoreFailure]
}

final class SafeFileOperationService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func isProtectedPath(_ path: String) -> Bool {
        SystemPathProtection.isProtected(path)
    }

    func moveToTrash(
        nodes: [FileNode],
        actionName: String,
        canModify: (_ urls: [URL], _ actionName: String) -> Bool,
        permissionHint: () -> String?
    ) -> SafeTrashOutcome {
        var moved: [SafeTrashMove] = []
        var skippedProtected: [String] = []
        var failures: [SafeTrashFailure] = []
        var blockedPermissionHint: String?

        for node in nodes {
            let path = node.url.path
            if isProtectedPath(path) {
                skippedProtected.append(path)
                continue
            }

            if !canModify([node.url], actionName) {
                failures.append(
                    SafeTrashFailure(
                        path: path,
                        reason: permissionHint() ?? "Unknown permissions block",
                        isPermission: true
                    )
                )
                if blockedPermissionHint == nil {
                    blockedPermissionHint = permissionHint()
                }
                continue
            }

            do {
                var trashedURL: NSURL?
                try fileManager.trashItem(at: node.url, resultingItemURL: &trashedURL)
                if let trashedPath = (trashedURL as URL?)?.path {
                    moved.append(
                        SafeTrashMove(
                            originalPath: path,
                            trashedPath: trashedPath
                        )
                    )
                }
            } catch {
                failures.append(
                    SafeTrashFailure(
                        path: path,
                        reason: error.localizedDescription,
                        isPermission: false
                    )
                )
            }
        }

        return SafeTrashOutcome(
            moved: moved,
            skippedProtected: skippedProtected,
            failures: failures,
            blockedPermissionHint: blockedPermissionHint
        )
    }

    func restore(_ requests: [SafeRestoreRequest]) -> SafeRestoreOutcome {
        var restored: [SafeRestoreMove] = []
        var failures: [SafeRestoreFailure] = []

        for request in requests {
            let sourceURL = URL(fileURLWithPath: request.trashedPath)
            let originalURL = URL(fileURLWithPath: request.originalPath)

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                failures.append(
                    SafeRestoreFailure(
                        originalPath: request.originalPath,
                        trashedPath: request.trashedPath,
                        reason: "Trashed file not found"
                    )
                )
                continue
            }

            let destinationURL = uniqueRestoreURL(for: originalURL)

            do {
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                restored.append(
                    SafeRestoreMove(
                        originalPath: request.originalPath,
                        restoredPath: destinationURL.path,
                        trashedPath: request.trashedPath
                    )
                )
            } catch {
                failures.append(
                    SafeRestoreFailure(
                        originalPath: request.originalPath,
                        trashedPath: request.trashedPath,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return SafeRestoreOutcome(restored: restored, failures: failures)
    }

    func uniqueRestoreURL(for desiredURL: URL) -> URL {
        if !fileManager.fileExists(atPath: desiredURL.path) { return desiredURL }

        let folder = desiredURL.deletingLastPathComponent()
        let ext = desiredURL.pathExtension
        let base = desiredURL.deletingPathExtension().lastPathComponent
        var idx = 1

        while idx < 10_000 {
            let candidateName = ext.isEmpty ? "\(base) (\(idx))" : "\(base) (\(idx)).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            idx += 1
        }
        return folder.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
    }
}
