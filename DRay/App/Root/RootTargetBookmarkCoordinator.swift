import Foundation

@MainActor
enum RootTargetBookmarkCoordinator {
    static func persistAndResolveBookmark(
        for url: URL,
        store: any UISettingsStoring
    ) -> URL? {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            store.saveSelectedTargetBookmark(bookmark)

            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return resolvedURL
        } catch {
            return nil
        }
    }

    static func restoreLastTarget(store: any UISettingsStoring) -> URL? {
        guard let data = store.loadSelectedTargetBookmark() else { return nil }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            store.clearSelectedTargetBookmark()
            return nil
        }
    }

    static func clearSavedTargetBookmark(store: any UISettingsStoring) {
        store.clearSelectedTargetBookmark()
    }
}
