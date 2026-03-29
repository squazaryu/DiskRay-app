import Foundation
import CryptoKit

struct DuplicateFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64
    let modifiedAt: Date?

    var name: String {
        url.lastPathComponent
    }
}

struct DuplicateGroup: Identifiable, Sendable {
    let id = UUID()
    let signature: String
    let files: [DuplicateFile]
    let sizeInBytes: Int64

    var reclaimableBytes: Int64 {
        Int64(max(0, files.count - 1)) * sizeInBytes
    }
}

struct DuplicateScanProgress: Sendable {
    let phase: String
    let currentPath: String
    let visitedFiles: Int
    let candidateGroups: Int
}

actor DuplicateFinderService {
    private struct CandidateFile: Sendable {
        let url: URL
        let sizeInBytes: Int64
        let modifiedAt: Date?
    }

    func scan(
        roots: [URL],
        minFileSizeBytes: Int64 = 10 * 1_048_576,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)? = nil
    ) async -> [DuplicateGroup] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        var bySize: [Int64: [CandidateFile]] = [:]
        var visitedFiles = 0

        for root in roots {
            if Task.isCancelled { return [] }
            let started = root.startAccessingSecurityScopedResource()
            defer {
                if started { root.stopAccessingSecurityScopedResource() }
            }

            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { return [] }
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }

                let size = Int64(values.fileSize ?? 0)
                guard size >= minFileSizeBytes else { continue }

                let candidate = CandidateFile(
                    url: fileURL,
                    sizeInBytes: size,
                    modifiedAt: values.contentModificationDate
                )
                bySize[size, default: []].append(candidate)
                visitedFiles += 1

                if visitedFiles.isMultiple(of: 250) {
                    let candidateGroups = bySize.values.filter { $0.count > 1 }.count
                    onProgress?(
                        DuplicateScanProgress(
                            phase: "Scanning",
                            currentPath: fileURL.path,
                            visitedFiles: visitedFiles,
                            candidateGroups: candidateGroups
                        )
                    )
                }
            }
        }

        let candidateBuckets = bySize
            .filter { $0.value.count > 1 }
            .sorted { $0.key > $1.key }

        var hashedFiles = 0
        var grouped: [String: [CandidateFile]] = [:]

        for (size, files) in candidateBuckets {
            for file in files {
                if Task.isCancelled { return [] }
                guard let hash = sha256Hex(for: file.url) else { continue }
                let signature = "\(size):\(hash)"
                grouped[signature, default: []].append(file)
                hashedFiles += 1
                if hashedFiles.isMultiple(of: 20) {
                    onProgress?(
                        DuplicateScanProgress(
                            phase: "Hashing",
                            currentPath: file.url.path,
                            visitedFiles: visitedFiles,
                            candidateGroups: candidateBuckets.count
                        )
                    )
                }
            }
        }

        let groups = grouped
            .compactMap { signature, files -> DuplicateGroup? in
                guard files.count > 1 else { return nil }
                let sortedFiles = files.sorted {
                    let lhsDate = $0.modifiedAt ?? .distantPast
                    let rhsDate = $1.modifiedAt ?? .distantPast
                    if lhsDate != rhsDate { return lhsDate > rhsDate }
                    return $0.url.path < $1.url.path
                }
                return DuplicateGroup(
                    signature: signature,
                    files: sortedFiles.map {
                        DuplicateFile(url: $0.url, sizeInBytes: $0.sizeInBytes, modifiedAt: $0.modifiedAt)
                    },
                    sizeInBytes: sortedFiles.first?.sizeInBytes ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.reclaimableBytes != rhs.reclaimableBytes {
                    return lhs.reclaimableBytes > rhs.reclaimableBytes
                }
                return lhs.files.count > rhs.files.count
            }

        onProgress?(
            DuplicateScanProgress(
                phase: "Completed",
                currentPath: roots.first?.path ?? "/",
                visitedFiles: visitedFiles,
                candidateGroups: groups.count
            )
        )
        return groups
    }

    private func sha256Hex(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            if Task.isCancelled { return nil }
            guard let chunk = try? handle.read(upToCount: 512 * 1024) else {
                break
            }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
