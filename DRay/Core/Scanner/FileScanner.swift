import Foundation

actor FileScanner {
    private let excludedPrefixes = [
        "/System/Volumes",
        "/private/var/vm"
    ]
    private var isCancelled = false
    private var isPaused = false

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    func cancel() {
        isCancelled = true
    }

    func scan(
        rootURL: URL,
        maxDepth: Int = 6,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> FileNode {
        isCancelled = false
        isPaused = false
        var visitedItems = 0
        let started = rootURL.startAccessingSecurityScopedResource()
        defer {
            if started { rootURL.stopAccessingSecurityScopedResource() }
        }
        return await scanNode(
            at: rootURL,
            depthRemaining: maxDepth,
            visitedItems: &visitedItems,
            onProgress: onProgress
        )
    }

    private func scanNode(
        at url: URL,
        depthRemaining: Int,
        visitedItems: inout Int,
        onProgress: (@Sendable (ScanProgress) -> Void)?
    ) async -> FileNode {
        if isCancelled {
            return FileNode(url: url, name: url.lastPathComponent, isDirectory: false, sizeInBytes: 0, children: [])
        }
        while isPaused {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        let fm = FileManager.default
        let name = (url.path as NSString).lastPathComponent.isEmpty ? url.path : (url.path as NSString).lastPathComponent
        visitedItems += 1
        onProgress?(ScanProgress(currentPath: url.path, visitedItems: visitedItems))

        var isDirectory: ObjCBool = false
        let exists = fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            return FileNode(url: url, name: name, isDirectory: false, sizeInBytes: 0, children: [])
        }

        if !isDirectory.boolValue {
            let size = quickFileSize(at: url)
            return FileNode(url: url, name: name, isDirectory: false, sizeInBytes: size, children: [])
        }

        if excludedPrefixes.contains(where: { url.path.hasPrefix($0) }) {
            return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: quickDirectorySize(at: url), children: [])
        }

        if depthRemaining <= 0 {
            return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: quickDirectorySize(at: url), children: [])
        }

        let urls: [URL]
        do {
            urls = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        } catch {
            return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: quickDirectorySize(at: url), children: [])
        }

        var children: [FileNode] = []
        children.reserveCapacity(urls.count)

        for childURL in urls {
            let child = await scanNode(
                at: childURL,
                depthRemaining: depthRemaining - 1,
                visitedItems: &visitedItems,
                onProgress: onProgress
            )
            children.append(child)
            if isCancelled { break }
        }

        let total = children.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let resolvedSize = total > 0 ? total : quickDirectorySize(at: url)
        return FileNode(url: url, name: name, isDirectory: true, sizeInBytes: resolvedSize, children: children)
    }

    private func quickFileSize(at url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.fileAllocatedSizeKey, .fileSizeKey])
            if let allocated = values.fileAllocatedSize {
                return Int64(allocated)
            }
            if let raw = values.fileSize {
                return Int64(raw)
            }
            return 0
        } catch {
            return 0
        }
    }

    private func quickDirectorySize(at url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .totalFileSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
            )
            if let allocatedTotal = values.totalFileAllocatedSize {
                return Int64(allocatedTotal)
            }
            if let total = values.totalFileSize {
                return Int64(total)
            }
            if let allocated = values.fileAllocatedSize {
                return Int64(allocated)
            }
            if let file = values.fileSize {
                return Int64(file)
            }
            return 0
        } catch {
            return 0
        }
    }
}
