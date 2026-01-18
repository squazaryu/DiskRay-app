import SwiftUI

struct SearchView: View {
    @ObservedObject var model: RootViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search by name or path...", text: $model.searchQuery)
                    .textFieldStyle(.roundedBorder)

                if model.isLoading {
                    ProgressView()
                }
            }

            if model.searchQuery.isEmpty {
                ContentUnavailableView("Search Index", systemImage: "magnifyingglass", description: Text("Type query after scan completes."))
            } else {
                Table(model.searchResults) {
                    TableColumn("Name") { node in
                        Text(node.name)
                    }
                    TableColumn("Size") { node in
                        Text(node.formattedSize)
                    }
                    TableColumn("Path") { node in
                        Text(node.url.path)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}
