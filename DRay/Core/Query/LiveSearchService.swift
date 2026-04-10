import Foundation

struct LiveSearchRequest: Sendable {
    let rootURL: URL
    let query: String
    let useRegex: Bool
    let pathContains: String
    let ownerContains: String
    let minSizeBytes: Int64
    let depthMin: Int
    let depthMax: Int
    let modifiedWithinDays: Int?
    let nodeType: QueryEngine.SearchNodeType
    let onlyDirectories: Bool
    let onlyFiles: Bool
    let excludeTrash: Bool
    let includeHidden: Bool
    let includePackageContents: Bool
    let limit: Int
}

actor LiveSearchService {
    func search(_ request: LiveSearchRequest) -> [FileNode] {
        let rootURL = request.rootURL
        let started = rootURL.startAccessingSecurityScopedResource()
        defer {
            if started { rootURL.stopAccessingSecurityScopedResource() }
        }

        let regex = request.useRegex ? (try? NSRegularExpression(pattern: request.query, options: [.caseInsensitive])) : nil
        let cutoff: Date? = request.modifiedWithinDays.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? .distantPast }
        let rootComponents = rootURL.pathComponents.count
        let fm = FileManager.default

        var options: FileManager.DirectoryEnumerationOptions = []
        if !request.includeHidden {
            options.insert(.skipsHiddenFiles)
        }
        if !request.includePackageContents {
            options.insert(.skipsPackageDescendants)
        }

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        ) else { return [] }

        var results: [FileNode] = []
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            if request.excludeTrash && isTrashPath(fileURL.path) {
                if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let depth = max(0, fileURL.pathComponents.count - rootComponents)
            if depth > request.depthMax {
                enumerator.skipDescendants()
                continue
            }
            if depth < request.depthMin { continue }

            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                continue
            }
            let isDir = values.isDirectory == true
            let size = Int64(values.fileSize ?? 0)

            let queryMatch: Bool
            if let regex {
                let text = fileURL.path
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                queryMatch = regex.firstMatch(in: text, options: [], range: range) != nil
            } else {
                let lower = request.query.lowercased()
                queryMatch = fileURL.lastPathComponent.lowercased().contains(lower) || fileURL.path.lowercased().contains(lower)
            }
            guard queryMatch else { continue }
            guard request.pathContains.isEmpty || fileURL.path.lowercased().contains(request.pathContains) else { continue }

            if !request.ownerContains.isEmpty {
                let owner = (try? fm.attributesOfItem(atPath: fileURL.path)[.ownerAccountName] as? String) ?? ""
                guard owner.lowercased().contains(request.ownerContains) else { continue }
            }
            guard size >= request.minSizeBytes else { continue }
            if let cutoff, let modified = values.contentModificationDate {
                guard modified >= cutoff else { continue }
            } else if cutoff != nil {
                continue
            }
            guard (!request.onlyDirectories || isDir) && (!request.onlyFiles || !isDir) else { continue }
            guard matchesNodeTypeLive(isDirectory: isDir, url: fileURL, nodeType: request.nodeType) else { continue }

            results.append(FileNode(
                url: fileURL,
                name: fileURL.lastPathComponent,
                isDirectory: isDir,
                sizeInBytes: size,
                children: []
            ))
            if results.count >= request.limit { break }
        }

        return results.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func isTrashPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.contains("/.trash/") ||
            lower.hasSuffix("/.trash") ||
            lower.contains("/.trashes/") ||
            lower.hasSuffix("/.trashes")
    }

    private func matchesNodeTypeLive(isDirectory: Bool, url: URL, nodeType: QueryEngine.SearchNodeType) -> Bool {
        switch nodeType {
        case .any: return true
        case .file: return !isDirectory
        case .directory: return isDirectory
        case .package: return isDirectory && url.pathExtension == "app"
        }
    }
}
