import Foundation

actor FileScanner {
    private let excludedPrefixes = [
        "/System/Volumes",
        "/private/var/vm"
    ]

    func scan(rootURL: URL) async -> FileNode {
        await scanNode(at: rootURL)
    }

    private func scanNode(at url: URL) async -> FileNode {
        let fm = FileManager.default
        let name = (url.path as NSString).lastPathComponent.isEmpty ? url.path : (url.path as NSString).lastPathComponent

        var isDirectory: ObjCBool = false
        let exists = fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            return FileNode(url: url, name: name, isDirectory: false, sizeInBytes: 0, children: [])
        }

        if !isDirectory.boolValue {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return FileNode(url: url, name: name, isDirectory: false, sizeInBytes: size, children: [])
        }

        if excludedPrefixes.contains(where: { url.path.hasPrefix($0) }) {
            return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: 0, children: [])
        }

        let urls: [URL]
        do {
            urls = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        } catch {
            return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: 0, children: [])
        }

        var children: [FileNode] = []
        children.reserveCapacity(urls.count)

        for childURL in urls {
            let child = await scanNode(at: childURL)
            children.append(child)
        }

        let total = children.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: total, children: children)
    }
}
