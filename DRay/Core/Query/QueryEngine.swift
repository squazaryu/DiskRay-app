import Foundation

struct QueryEngine {
    func search(
        in root: FileNode,
        query: String,
        minSizeBytes: Int64 = 0,
        pathContains: String = "",
        onlyDirectories: Bool = false,
        onlyFiles: Bool = false,
        limit: Int = 300
    ) -> [FileNode] {
        let normalized = query.lowercased()
        let pathFilter = pathContains.lowercased()
        let nodes = root.flattened.filter {
            let queryMatch = $0.name.lowercased().contains(normalized) ||
            $0.url.path.lowercased().contains(normalized)
            let sizeMatch = $0.sizeInBytes >= minSizeBytes
            let pathMatch = pathFilter.isEmpty || $0.url.path.lowercased().contains(pathFilter)
            let typeMatch = (!onlyDirectories || $0.isDirectory) && (!onlyFiles || !$0.isDirectory)
            return queryMatch && sizeMatch && pathMatch && typeMatch
        }
        return Array(nodes.prefix(limit)).sorted { $0.sizeInBytes > $1.sizeInBytes }
    }
}
