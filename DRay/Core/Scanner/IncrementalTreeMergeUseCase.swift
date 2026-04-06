import Foundation

struct IncrementalTreeMergeUseCase {
    func merge(base: FileNode, delta: FileNode) -> FileNode {
        var byPath = Dictionary(uniqueKeysWithValues: base.children.map { ($0.url.path, $0) })
        for updated in delta.children {
            if updated.url.path == base.url.path { continue }
            if let existing = byPath[updated.url.path] {
                byPath[updated.url.path] = mergeNode(existing: existing, updated: updated)
            } else {
                byPath[updated.url.path] = updated
            }
        }
        let children = Array(byPath.values).sorted { $0.sizeInBytes > $1.sizeInBytes }
        let total = children.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return FileNode(
            url: base.url,
            name: base.name,
            isDirectory: true,
            sizeInBytes: total,
            children: children
        )
    }

    private func mergeChildrenByPath(base: [FileNode], delta: [FileNode]) -> [FileNode] {
        var byPath = Dictionary(uniqueKeysWithValues: base.map { ($0.url.path, $0) })
        for node in delta {
            if let existing = byPath[node.url.path] {
                byPath[node.url.path] = mergeNode(existing: existing, updated: node)
            } else {
                byPath[node.url.path] = node
            }
        }
        return Array(byPath.values).sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func mergeNode(existing: FileNode, updated: FileNode) -> FileNode {
        let mergedChildren = mergeChildrenByPath(base: existing.children, delta: updated.children)
        let mergedSize = updated.sizeInBytes > 0 ? updated.sizeInBytes : existing.sizeInBytes
        return FileNode(
            url: existing.url,
            name: existing.name,
            isDirectory: existing.isDirectory,
            sizeInBytes: mergedSize,
            children: mergedChildren
        )
    }
}
