import SwiftUI

struct RecoveryView: View {
    @ObservedObject var model: RootViewModel
    @State private var selected = Set<RecentlyDeletedItem.ID>()
    @State private var showRestoreFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery")
                        .font(.title2.bold())
                    Text("Restore recently deleted items from DRay history.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restore Selected") {
                    let items = model.recentlyDeleted.filter { selected.contains($0.id) }
                    for item in items {
                        if !model.restoreDeletedItem(item) {
                            showRestoreFailed = true
                        }
                    }
                    selected.removeAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }

            if model.recentlyDeleted.isEmpty {
                ContentUnavailableView(
                    "No Recently Deleted Items",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Deleted items will appear here with restore options.")
                )
            } else {
                Table(model.recentlyDeleted, selection: $selected) {
                    TableColumn("Name") { item in
                        Text(item.name)
                    }
                    TableColumn("Original Path") { item in
                        Text(item.originalPath).lineLimit(1)
                    }
                    TableColumn("Deleted") { item in
                        Text(item.deletedAt, style: .relative)
                    }
                    TableColumn("Actions") { item in
                        HStack {
                            Button("Restore") {
                                if !model.restoreDeletedItem(item) {
                                    showRestoreFailed = true
                                }
                            }
                            Button("Reveal") {
                                model.revealInFinder(
                                    FileNode(
                                        url: URL(fileURLWithPath: item.trashedPath),
                                        name: item.name,
                                        isDirectory: false,
                                        sizeInBytes: 0,
                                        children: []
                                    )
                                )
                            }
                            Button("Remove") {
                                model.removeDeletedHistoryItem(item)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .alert("Restore failed", isPresented: $showRestoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not restore one or more selected items.")
        }
    }
}
