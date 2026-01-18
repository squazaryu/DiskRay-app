import Foundation

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var root: FileNode?
    @Published private(set) var isLoading = false
    @Published var searchQuery = ""

    private let scanner = FileScanner()
    private let queryEngine = QueryEngine()

    var searchResults: [FileNode] {
        guard let root else { return [] }
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return queryEngine.search(in: root, query: searchQuery)
    }

    func refresh(at url: URL = URL(fileURLWithPath: "/")) {
        isLoading = true
        Task {
            let scanned = await scanner.scan(rootURL: url)
            root = scanned
            isLoading = false
        }
    }
}
