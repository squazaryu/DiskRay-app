import Foundation
import AppKit

@MainActor
protocol WorkspaceActioning {
    func reveal(_ urls: [URL])
    func open(_ url: URL)
}

@MainActor
final class WorkspaceActionService: WorkspaceActioning {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        workspace.activateFileViewerSelecting(urls)
    }

    func open(_ url: URL) {
        workspace.open(url)
    }
}
