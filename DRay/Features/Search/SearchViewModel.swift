import SwiftUI
import Combine

struct SearchScopeChoice: Identifiable, Hashable {
    let id: String
    let mode: SearchScopeMode
    let path: String
    let title: String
}

@MainActor
final class SearchViewModel: ObservableObject {
    private let root: RootViewModel
    private let searchController: SearchFeatureController
    private var rootChangeCancellable: AnyCancellable?
    private var searchChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.searchController = root.search
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.searchChangeCancellable = root.search.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var search: SearchFeatureState {
        searchController.state
    }

    var isLoading: Bool {
        root.isLoading
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    var searchScopeChoices: [SearchScopeChoice] {
        var seen = Set<String>()
        var items: [SearchScopeChoice] = []

        let startup = SearchScopeChoice(
            id: "scope.startup",
            mode: .startupDisk,
            path: "/",
            title: t("Системный диск (/)", "Startup Disk (/)")
        )
        items.append(startup)
        seen.insert("/")

        let selected = root.selectedTarget.url.standardizedFileURL.path
        if selected != "/" {
            items.append(
                SearchScopeChoice(
                    id: "scope.selected",
                    mode: .selectedTarget,
                    path: selected,
                    title: "\(t("Выбранная цель", "Selected Target")): \(root.selectedTarget.name)"
                )
            )
            seen.insert(selected)
        }

        let keys: [URLResourceKey] = [.volumeNameKey]
        let mounted = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        for url in mounted {
            let path = url.standardizedFileURL.path
            if seen.contains(path) { continue }
            let name = (try? url.resourceValues(forKeys: Set(keys)).volumeName) ?? url.lastPathComponent
            items.append(
                SearchScopeChoice(
                    id: "scope.volume.\(path)",
                    mode: .customPath,
                    path: path,
                    title: name.isEmpty ? path : name
                )
            )
            seen.insert(path)
        }

        return items
    }

    var activeScopeLabel: String {
        switch search.scopeMode {
        case .startupDisk:
            return t("Системный диск (/)", "Startup Disk (/)")
        case .selectedTarget:
            return "\(t("Выбранная цель", "Selected Target")): \(root.selectedTarget.name)"
        case .customPath:
            if let choice = searchScopeChoices.first(where: { $0.mode == .customPath && $0.path == search.customScopePath }) {
                return choice.title
            }
            return search.customScopePath
        }
    }

    var activeScopePath: String {
        switch search.scopeMode {
        case .startupDisk:
            return "/"
        case .selectedTarget:
            return root.selectedTarget.url.path
        case .customPath:
            return search.customScopePath
        }
    }

    func selectScope(_ choice: SearchScopeChoice) {
        searchController.update(\.scopeMode, value: choice.mode)
        if choice.mode == .customPath {
            searchController.update(\.customScopePath, value: choice.path)
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<SearchFeatureState, Value>) -> Binding<Value> {
        Binding(
            get: { [weak self] in
                guard let self else { return SearchFeatureState()[keyPath: keyPath] }
                return self.searchController.state[keyPath: keyPath]
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.searchController.update(keyPath, value: newValue)
            }
        )
    }

    func triggerSearch() {
        searchController.setSelectedTargetURL(root.selectedTarget.url)
        searchController.runSearch()
    }

    func cancelSearch() {
        searchController.cancelSearch()
    }

    func savePreset(named name: String) {
        searchController.savePreset(name: name)
    }

    func applyPreset(_ preset: SearchPreset) {
        searchController.setSelectedTargetURL(root.selectedTarget.url)
        searchController.applyPreset(id: preset.id)
    }

    func deletePreset(_ preset: SearchPreset) {
        searchController.deletePreset(id: preset.id)
    }

    func moveToTrash(nodes: [FileNode]) -> TrashOperationResult {
        root.moveToTrash(nodes: nodes)
    }

    func revealInFinder(_ node: FileNode) {
        root.revealInFinder(node)
    }

    func openItem(_ node: FileNode) {
        root.openItem(node)
    }

    func trashResultMessage(_ result: TrashOperationResult) -> String {
        root.trashResultMessage(result)
    }

    private var isRussian: Bool {
        root.appLanguage.localeCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }
}
