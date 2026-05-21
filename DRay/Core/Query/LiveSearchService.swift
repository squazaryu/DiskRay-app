import Foundation

struct LiveSearchRequest: Sendable {
    let rootURL: URL
    let query: String
    let mode: SearchExecutionMode
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

enum LiveSearchValidationError: Error, Equatable, Sendable {
    case invalidRegularExpression

    var message: String {
        switch self {
        case .invalidRegularExpression:
            return "Invalid regular expression"
        }
    }
}

actor LiveSearchService {
    private let commandRunner: SystemCommandRunner

    init(commandRunner: SystemCommandRunner = .live) {
        self.commandRunner = commandRunner
    }

    func search(_ request: LiveSearchRequest) async throws -> [FileNode] {
        let rootURL = request.rootURL
        let started = rootURL.startAccessingSecurityScopedResource()
        defer {
            if started { rootURL.stopAccessingSecurityScopedResource() }
        }

        if request.mode == .live, !request.useRegex {
            if let indexedResults = try await indexedSearch(request) {
                if !indexedResults.isEmpty || !shouldFallbackToEnumerator(afterEmptyIndexedFor: request) {
                    return indexedResults
                }
            } else {
                if request.rootURL.standardizedFileURL.path == "/" {
                    return []
                }
                return try enumeratorSearch(request)
            }
        }

        return try enumeratorSearch(request)
    }

    private func indexedSearch(_ request: LiveSearchRequest) async throws -> [FileNode]? {
        let fm = FileManager.default
        let context = try makeFilterContext(for: request)
        guard let candidatePaths = await mdfindPaths(for: request) else {
            return nil
        }
        if candidatePaths.isEmpty {
            return []
        }

        var uniquePaths = Set<String>()
        var results: [FileNode] = []
        results.reserveCapacity(min(request.limit, candidatePaths.count))

        for path in candidatePaths {
            if Task.isCancelled { break }
            let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
            if !uniquePaths.insert(standardizedPath).inserted { continue }

            let url = URL(fileURLWithPath: standardizedPath)
            if let node = buildNodeIfMatch(url: url, request: request, context: context, fileManager: fm) {
                results.append(node)
                if results.count >= request.limit {
                    break
                }
            }
        }

        return results.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func enumeratorSearch(_ request: LiveSearchRequest) throws -> [FileNode] {
        let context = try makeFilterContext(for: request)
        let fm = FileManager.default

        var options: FileManager.DirectoryEnumerationOptions = []
        if !request.includeHidden {
            options.insert(.skipsHiddenFiles)
        }
        if !request.includePackageContents {
            options.insert(.skipsPackageDescendants)
        }

        guard let enumerator = fm.enumerator(
            at: request.rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        ) else { return [] }

        var results: [FileNode] = []
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            let depth = max(0, fileURL.pathComponents.count - context.rootComponents)
            if depth > request.depthMax {
                enumerator.skipDescendants()
                continue
            }

            if let node = buildNodeIfMatch(url: fileURL, request: request, context: context, fileManager: fm) {
                results.append(node)
            } else if request.excludeTrash && isTrashPath(fileURL.path) {
                if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
            }
            if results.count >= request.limit { break }
        }

        return results.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func buildNodeIfMatch(
        url: URL,
        request: LiveSearchRequest,
        context: FilterContext,
        fileManager: FileManager
    ) -> FileNode? {
        let path = url.standardizedFileURL.path
        if request.excludeTrash && isTrashPath(path) { return nil }

        let depth = max(0, url.pathComponents.count - context.rootComponents)
        guard depth >= request.depthMin, depth <= request.depthMax else { return nil }

        let lowerPath = path.lowercased()
        guard request.pathContains.isEmpty || lowerPath.contains(request.pathContains) else { return nil }
        guard request.query.isEmpty == false else { return nil }

        let queryMatch: Bool
        if let regex = context.regex {
            let range = NSRange(path.startIndex..<path.endIndex, in: path)
            queryMatch = regex.firstMatch(in: path, options: [], range: range) != nil
        } else {
            let lowerName = url.lastPathComponent.lowercased()
            queryMatch = lowerName.contains(context.normalizedQuery) || lowerPath.contains(context.normalizedQuery)
        }
        guard queryMatch else { return nil }

        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey]) else {
            return nil
        }
        let isDirectory = values.isDirectory == true
        let size = Int64(values.fileSize ?? 0)

        if !request.includeHidden,
           values.isHidden == true || containsHiddenPathComponent(path) {
            return nil
        }

        if !request.includePackageContents,
           appearsInsidePackage(path: path, isDirectory: isDirectory) {
            return nil
        }

        if !request.ownerContains.isEmpty {
            let owner = (try? fileManager.attributesOfItem(atPath: path)[.ownerAccountName] as? String) ?? ""
            guard owner.lowercased().contains(request.ownerContains) else { return nil }
        }

        guard size >= request.minSizeBytes else { return nil }
        if let cutoff = context.cutoff {
            guard let modified = values.contentModificationDate, modified >= cutoff else {
                return nil
            }
        }

        guard (!request.onlyDirectories || isDirectory) && (!request.onlyFiles || !isDirectory) else { return nil }
        guard matchesNodeTypeLive(isDirectory: isDirectory, url: url, nodeType: request.nodeType) else { return nil }

        return FileNode(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDirectory,
            sizeInBytes: size,
            children: []
        )
    }

    private struct FilterContext {
        let normalizedQuery: String
        let regex: NSRegularExpression?
        let cutoff: Date?
        let rootComponents: Int
    }

    private func makeFilterContext(for request: LiveSearchRequest) throws -> FilterContext {
        let regex: NSRegularExpression?
        if request.useRegex {
            do {
                regex = try NSRegularExpression(pattern: request.query, options: [.caseInsensitive])
            } catch {
                throw LiveSearchValidationError.invalidRegularExpression
            }
        } else {
            regex = nil
        }
        let cutoff: Date? = request.modifiedWithinDays.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? .distantPast
        }
        return FilterContext(
            normalizedQuery: request.query.lowercased(),
            regex: regex,
            cutoff: cutoff,
            rootComponents: request.rootURL.pathComponents.count
        )
    }

    private func mdfindPaths(for request: LiveSearchRequest) async -> [String]? {
        let rootPath = request.rootURL.standardizedFileURL.path
        let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateBudget = max(request.limit * 6, request.limit + 256)
        var arguments = ["-0", "-onlyin", rootPath]

        if query.contains("/") {
            let escapedQuery = query
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let expression = "kMDItemPath ==[cdw] \"*\(escapedQuery)*\" || kMDItemFSName ==[cdw] \"*\(escapedQuery)*\""
            arguments.append(expression)
        } else {
            arguments.append(contentsOf: ["-name", query])
        }
        let result = await commandRunner.run(
            executablePath: "/usr/bin/mdfind",
            arguments: arguments,
            timeoutSeconds: 8
        )
        guard result.succeeded, let data = result.stdout.data(using: .utf8) else {
            return nil
        }
        return splitNullSeparatedPaths(data, limit: candidateBudget)
    }

    private func splitNullSeparatedPaths(_ data: Data, limit: Int) -> [String] {
        guard !data.isEmpty else { return [] }
        var paths: [String] = []
        paths.reserveCapacity(min(limit, 2_048))

        var start = data.startIndex
        var index = data.startIndex
        while index < data.endIndex {
            if data[index] == 0 {
                if index > start,
                   let value = String(data: data[start..<index], encoding: .utf8),
                   !value.isEmpty {
                    paths.append(value)
                    if paths.count >= limit {
                        break
                    }
                }
                start = data.index(after: index)
            }
            index = data.index(after: index)
        }

        if paths.count < limit, start < data.endIndex,
           let tail = String(data: data[start..<data.endIndex], encoding: .utf8),
           !tail.isEmpty {
            paths.append(tail)
        }
        return paths
    }

    private func isTrashPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.contains("/.trash/") ||
            lower.hasSuffix("/.trash") ||
            lower.contains("/.trashes/") ||
            lower.hasSuffix("/.trashes")
    }

    private func containsHiddenPathComponent(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        for component in components where component.hasPrefix(".") {
            if component == "." || component == ".." { continue }
            return true
        }
        return false
    }

    private func appearsInsidePackage(path: String, isDirectory: Bool) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        let limit = isDirectory ? max(components.count - 1, 0) : components.count
        guard limit > 0 else { return false }
        for index in 0..<limit {
            let component = components[index].lowercased()
            if component.hasSuffix(".app") ||
                component.hasSuffix(".bundle") ||
                component.hasSuffix(".framework") ||
                component.hasSuffix(".plugin") ||
                component.hasSuffix(".appex") ||
                component.hasSuffix(".xpc") ||
                component.hasSuffix(".pkg") {
                return true
            }
        }
        return false
    }

    private func shouldFallbackToEnumerator(afterEmptyIndexedFor request: LiveSearchRequest) -> Bool {
        let rootPath = request.rootURL.standardizedFileURL.path
        if rootPath == "/" {
            return false
        }
        if rootPath.hasPrefix("/Volumes/"), rootPath.split(separator: "/").count <= 2 {
            return false
        }
        return true
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
