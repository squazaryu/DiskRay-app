import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    private let root: RootViewModel
    private var rootChangeCancellable: AnyCancellable?

    init(root: RootViewModel) {
        self.root = root
        self.rootChangeCancellable = root.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var search: SearchFeatureState {
        root.search
    }

    var isLoading: Bool {
        root.isLoading
    }

    var appLanguage: AppLanguage {
        root.appLanguage
    }

    func binding<Value>(_ keyPath: WritableKeyPath<SearchFeatureState, Value>) -> Binding<Value> {
        Binding(
            get: { [weak self] in
                guard let self else { return SearchFeatureState()[keyPath: keyPath] }
                return self.root.search[keyPath: keyPath]
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.root.search[keyPath: keyPath] = newValue
            }
        )
    }

    func triggerSearch() {
        root.triggerLiveSearch()
    }

    func cancelSearch() {
        root.cancelLiveSearch()
    }

    func savePreset(named name: String) {
        root.saveCurrentSearchPreset(named: name)
    }

    func applyPreset(_ preset: SearchPreset) {
        root.applySearchPreset(preset)
    }

    func deletePreset(_ preset: SearchPreset) {
        root.deletePreset(preset)
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
}
