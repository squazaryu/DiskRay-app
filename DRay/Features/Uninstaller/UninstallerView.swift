import SwiftUI

struct UninstallerView: View {
    @ObservedObject var model: RootViewModel
    @State private var selectedApp: InstalledApp?
    @State private var showUninstallConfirm = false

    var body: some View {
        NavigationSplitView {
            List(model.installedApps, selection: $selectedApp) { app in
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if model.isUninstallerLoading {
                    ProgressView("Loading apps...")
                }
            }
            .onAppear {
                if model.installedApps.isEmpty {
                    model.loadInstalledApps()
                }
            }
            .onChange(of: selectedApp?.id) {
                guard let selectedApp else { return }
                model.loadRemnants(for: selectedApp)
            }
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                if let selectedApp {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(selectedApp.name)
                                .font(.title3.bold())
                            Text(selectedApp.appURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Uninstall", role: .destructive) {
                            showUninstallConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Text("Detected remnants: \(model.uninstallerRemnants.count)")
                        .font(.subheadline)

                    List(model.uninstallerRemnants) { remnant in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(remnant.name)
                                Text(remnant.url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: remnant.sizeInBytes, countStyle: .file))
                                .font(.caption)
                        }
                    }
                } else {
                    ContentUnavailableView("Uninstaller", systemImage: "trash", description: Text("Select app to inspect remnants."))
                }
            }
            .padding()
            .confirmationDialog(
                "Uninstall app and move detected remnants to Trash?",
                isPresented: $showUninstallConfirm,
                titleVisibility: .visible
            ) {
                Button("Uninstall", role: .destructive) {
                    guard let selectedApp else { return }
                    model.uninstall(app: selectedApp)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
