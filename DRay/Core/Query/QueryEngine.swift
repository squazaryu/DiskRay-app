import Foundation

struct QueryEngine {
    func search(in root: FileNode, query: String, limit: Int = 300) -> [FileNode] {
        let normalized = query.lowercased()
        let nodes = root.flattened.filter {
            $0.name.lowercased().contains(normalized) ||
            $0.url.path.lowercased().contains(normalized)
        }
        return Array(nodes.prefix(limit)).sorted { $0.sizeInBytes > $1.sizeInBytes }
    }
}
