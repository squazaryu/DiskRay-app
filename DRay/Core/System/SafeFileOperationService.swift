import Foundation

struct SafeTrashMove: Sendable {
    let originalPath: String
    let trashedPath: String
}

struct SafeElevatedTrashMoveResult: Sendable {
    let success: Bool
    let trashedPath: String?
    let details: String
}

struct SafeTrashFailure: Sendable {
    let path: String
    let reason: String
    let isPermission: Bool
}

struct SafeTrashOutcome: Sendable {
    let moved: [SafeTrashMove]
    let elevatedMoved: [SafeTrashMove]
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
    typealias ElevatedTrashMover = (_ target: URL) -> SafeElevatedTrashMoveResult

    private let fileManager: FileManager
    private let elevatedTrashMover: ElevatedTrashMover

    init(
        fileManager: FileManager = .default,
        elevatedTrashMover: @escaping ElevatedTrashMover = SafeFileOperationService.moveToTrashWithAdministratorPrivileges
    ) {
        self.fileManager = fileManager
        self.elevatedTrashMover = elevatedTrashMover
    }

    func isProtectedPath(_ path: String) -> Bool {
        SystemPathProtection.isProtected(path)
    }

    func moveToTrash(
        nodes: [FileNode],
        actionName: String,
        allowElevatedDeletion: Bool = false,
        canModify: (_ urls: [URL], _ actionName: String) -> Bool,
        permissionHint: () -> String?
    ) -> SafeTrashOutcome {
        var moved: [SafeTrashMove] = []
        var elevatedMoved: [SafeTrashMove] = []
        var skippedProtected: [String] = []
        var failures: [SafeTrashFailure] = []
        var blockedPermissionHint: String?

        for node in normalizedTrashNodes(nodes) {
            let path = node.url.standardizedFileURL.path
            let targetURL = URL(fileURLWithPath: path)

            // If parent directory has already been moved, children should be
            // silently ignored instead of reported as permission failures.
            guard fileManager.fileExists(atPath: path) else {
                continue
            }

            if isProtectedPath(path) {
                skippedProtected.append(path)
                continue
            }

            if !canModify([targetURL], actionName) {
                let hint = permissionHint() ?? "Unknown permissions block"
                if allowElevatedDeletion {
                    let elevatedResult = elevatedTrashMover(targetURL)
                    if let elevatedMove = elevatedMove(targetURL: targetURL, result: elevatedResult) {
                        elevatedMoved.append(elevatedMove)
                        moved.append(elevatedMove)
                        continue
                    }

                    failures.append(
                        SafeTrashFailure(
                            path: path,
                            reason: "\(hint). Administrator authorization did not complete: \(elevatedResult.details)",
                            isPermission: true
                        )
                    )
                    if blockedPermissionHint == nil {
                        blockedPermissionHint = hint
                    }
                    continue
                }

                failures.append(
                    SafeTrashFailure(
                        path: path,
                        reason: hint,
                        isPermission: true
                    )
                )
                if blockedPermissionHint == nil {
                    blockedPermissionHint = hint
                }
                continue
            }

            do {
                var trashedURL: NSURL?
                try fileManager.trashItem(at: targetURL, resultingItemURL: &trashedURL)
                if let trashedPath = (trashedURL as URL?)?.path {
                    moved.append(
                        SafeTrashMove(
                            originalPath: path,
                            trashedPath: trashedPath
                        )
                    )
                }
            } catch {
                if allowElevatedDeletion, isPermissionError(error) {
                    let elevatedResult = elevatedTrashMover(targetURL)
                    if let elevatedMove = elevatedMove(targetURL: targetURL, result: elevatedResult) {
                        elevatedMoved.append(elevatedMove)
                        moved.append(elevatedMove)
                        continue
                    }

                    failures.append(
                        SafeTrashFailure(
                            path: path,
                            reason: "\(error.localizedDescription). Administrator authorization did not complete: \(elevatedResult.details)",
                            isPermission: true
                        )
                    )
                    continue
                }

                failures.append(
                    SafeTrashFailure(
                        path: path,
                        reason: error.localizedDescription,
                        isPermission: isPermissionError(error)
                    )
                )
            }
        }

        return SafeTrashOutcome(
            moved: moved,
            elevatedMoved: elevatedMoved,
            skippedProtected: skippedProtected,
            failures: failures,
            blockedPermissionHint: blockedPermissionHint
        )
    }

    private func elevatedMove(targetURL: URL, result elevatedResult: SafeElevatedTrashMoveResult) -> SafeTrashMove? {
        if elevatedResult.success, let trashedPath = elevatedResult.trashedPath {
            return SafeTrashMove(
                originalPath: targetURL.standardizedFileURL.path,
                trashedPath: trashedPath
            )
        }
        return nil
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteNoPermissionError,
                 NSFileWriteUnknownError,
                 NSFileWriteVolumeReadOnlyError:
                return true
            default:
                break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == EACCES || nsError.code == EPERM
        }
        let text = nsError.localizedDescription.lowercased()
        return text.contains("permission")
            || text.contains("operation not permitted")
            || text.contains("not permitted")
            || text.contains("denied")
    }

    private static func moveToTrashWithAdministratorPrivileges(target: URL) -> SafeElevatedTrashMoveResult {
        let trashRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
            .path
        let destination = "\(trashRoot)/\(UUID().uuidString)-\(target.lastPathComponent)"
        let script = """
        on run argv
            set targetPath to item 1 of argv
            set destinationPath to item 2 of argv
            do shell script "/bin/mkdir -p \"$(/usr/bin/dirname " & quoted form of destinationPath & ")\"; /bin/mv -f " & quoted form of targetPath & " " & quoted form of destinationPath with administrator privileges
            return "ok"
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, target.path, destination]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return SafeElevatedTrashMoveResult(
                    success: true,
                    trashedPath: destination,
                    details: "Moved to Trash with macOS administrator authorization."
                )
            }

            let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return SafeElevatedTrashMoveResult(
                success: false,
                trashedPath: nil,
                details: output?.isEmpty == false ? output! : "osascript returned \(process.terminationStatus)"
            )
        } catch {
            return SafeElevatedTrashMoveResult(
                success: false,
                trashedPath: nil,
                details: error.localizedDescription
            )
        }
    }

    private func normalizedTrashNodes(_ nodes: [FileNode]) -> [FileNode] {
        var uniqueByPath: [String: FileNode] = [:]
        for node in nodes {
            let path = node.url.standardizedFileURL.path
            if uniqueByPath[path] == nil {
                uniqueByPath[path] = node
            }
        }

        let sorted = uniqueByPath.values.sorted { lhs, rhs in
            let leftPath = lhs.url.standardizedFileURL.path
            let rightPath = rhs.url.standardizedFileURL.path
            let leftDepth = leftPath.split(separator: "/").count
            let rightDepth = rightPath.split(separator: "/").count
            if leftDepth != rightDepth {
                return leftDepth < rightDepth
            }
            return leftPath < rightPath
        }

        var acceptedRoots: [String] = []
        var filtered: [FileNode] = []
        for node in sorted {
            let path = node.url.standardizedFileURL.path
            if acceptedRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                continue
            }
            acceptedRoots.append(path)
            filtered.append(node)
        }
        return filtered
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
