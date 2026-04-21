import Foundation

@MainActor
enum RootScanTargetCoordinator {
    static func startupDiskTarget() -> ScanTarget {
        ScanTarget(name: "Macintosh HD", url: URL(fileURLWithPath: "/"))
    }

    static func homeTarget(fileManager: FileManager = .default) -> ScanTarget {
        let home = fileManager.homeDirectoryForCurrentUser
        return ScanTarget(name: "Home", url: home)
    }

    static func customTarget(
        for url: URL,
        store: any UISettingsStoring
    ) -> ScanTarget {
        let resolvedURL = RootTargetBookmarkCoordinator
            .persistAndResolveBookmark(for: url, store: store) ?? url
        return ScanTarget(name: resolvedURL.lastPathComponent, url: resolvedURL)
    }

    static func initialTarget(
        defaultScanTarget: ScanDefaultTarget,
        store: any UISettingsStoring,
        fileManager: FileManager = .default
    ) -> ScanTarget {
        switch defaultScanTarget {
        case .startupDisk:
            return startupDiskTarget()
        case .home:
            return homeTarget(fileManager: fileManager)
        case .lastSelectedFolder:
            guard let restored = RootTargetBookmarkCoordinator.restoreLastTarget(store: store) else {
                return startupDiskTarget()
            }
            return ScanTarget(name: restored.lastPathComponent, url: restored)
        }
    }
}
