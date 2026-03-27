import Foundation

struct QueryEngine {
    enum SearchNodeType: String {
        case any
        case file
        case directory
        case package
    }

    func search(
        in root: FileNode,
        query: String,
        minSizeBytes: Int64 = 0,
        pathContains: String = "",
        ownerContains: String = "",
        onlyDirectories: Bool = false,
        onlyFiles: Bool = false,
        useRegex: Bool = false,
        depthMin: Int = 0,
        depthMax: Int = 128,
        modifiedWithinDays: Int? = nil,
        nodeType: SearchNodeType = .any,
        limit: Int = 300
    ) -> [FileNode] {
        let normalized = query.lowercased()
        let pathFilter = pathContains.lowercased()
        let ownerFilter = ownerContains.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rootComponents = root.url.pathComponents.count
        let regex = useRegex ? (try? NSRegularExpression(pattern: query, options: [.caseInsensitive])) : nil
        let modifiedCutoff: Date? = modifiedWithinDays.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? .distantPast }

        let nodes = root.flattened.filter {
            let queryMatch: Bool
            if useRegex, let regex {
                let full = $0.url.path
                let range = NSRange(full.startIndex..<full.endIndex, in: full)
                queryMatch = regex.firstMatch(in: full, options: [], range: range) != nil
            } else {
                queryMatch = $0.name.lowercased().contains(normalized) ||
                    $0.url.path.lowercased().contains(normalized)
            }
            let sizeMatch = $0.sizeInBytes >= minSizeBytes
            let pathMatch = pathFilter.isEmpty || $0.url.path.lowercased().contains(pathFilter)
            let ownerMatch = ownerFilter.isEmpty || ownerName(for: $0.url).lowercased().contains(ownerFilter)
            let typeMatch = (!onlyDirectories || $0.isDirectory) && (!onlyFiles || !$0.isDirectory)
            let depth = max(0, $0.url.pathComponents.count - rootComponents)
            let depthMatch = depth >= depthMin && depth <= depthMax
            let nodeTypeMatch = matchesNodeType($0, nodeType: nodeType)
            let modifiedMatch = matchesModified(node: $0, cutoff: modifiedCutoff)
            return queryMatch && sizeMatch && pathMatch && ownerMatch && typeMatch && depthMatch && nodeTypeMatch && modifiedMatch
        }
        return Array(nodes.prefix(limit)).sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func matchesNodeType(_ node: FileNode, nodeType: SearchNodeType) -> Bool {
        switch nodeType {
        case .any:
            return true
        case .file:
            return !node.isDirectory
        case .directory:
            return node.isDirectory
        case .package:
            return node.isDirectory && node.url.pathExtension == "app"
        }
    }

    private func matchesModified(node: FileNode, cutoff: Date?) -> Bool {
        guard let cutoff else { return true }
        guard let values = try? node.url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else { return false }
        return modified >= cutoff
    }

    private func ownerName(for url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let owner = attrs[.ownerAccountName] as? String else {
            return ""
        }
        return owner
    }
}
