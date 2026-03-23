import Foundation

struct FileNode: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let sizeInBytes: Int64
    let children: [FileNode]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    var flattened: [FileNode] {
        [self] + children.flatMap(\.flattened)
    }

    var largestChildren: [FileNode] {
        children.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }
}
