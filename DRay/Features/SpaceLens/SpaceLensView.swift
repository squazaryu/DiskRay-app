import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var model: RootViewModel

    var body: some View {
        NavigationSplitView {
            List {
                if let root = model.root {
                    Section("Largest") {
                        ForEach(root.largestChildren.prefix(20)) { node in
                            HStack {
                                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(node.name)
                                    Text(node.url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(node.formattedSize)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .overlay {
                if model.isLoading {
                    ProgressView("Scanning disk...")
                }
            }
        } detail: {
            Group {
                if let root = model.root {
                    BubbleMapView(root: root)
                } else {
                    ContentUnavailableView("No Data", systemImage: "externaldrive", description: Text("Run scan to render Space Lens."))
                }
            }
            .toolbar {
                Button("Rescan") {
                    model.refresh()
                }
            }
        }
    }
}
