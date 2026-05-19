import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void
    @State var showExperimentalElevatedDeletionConsent = false
    @State private var boardWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            ModuleHeaderCard(
                title: model.localized(.settingsTitle),
                subtitle: model.localized(.settingsSubtitle)
            ) {
                Button(model.localized(.settingsRefresh)) {
                    model.refreshPermissionsAsync()
                    model.refreshLaunchAtLoginStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView(.vertical, showsIndicators: true) {
                settingsBoard
                    .padding(.horizontal, 2)
                    .background(boardWidthProbe)
                    .environment(\.draySettingsIsCompactLayout, boardColumnCount == 1)

                settingsStatusStrip
                    .padding(.top, 12)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .onAppear {
            model.refreshPermissionsAsync()
            model.refreshLaunchAtLoginStatus()
        }
        .alert(
            tr("Экспериментальный полный доступ", "Experimental Full Access"),
            isPresented: $showExperimentalElevatedDeletionConsent
        ) {
            Button(tr("Включить", "Enable"), role: .destructive) {
                model.experimentalElevatedDeletionEnabled = true
            }
            Button(model.localized(.commonCancel), role: .cancel) {
                model.experimentalElevatedDeletionEnabled = false
            }
        } message: {
            Text(tr(
                "DRay будет пытаться перемещать отказанные файлы в Корзину через системный запрос администратора. Это не обходит SIP: системно-защищённые пути macOS всё равно останутся заблокированы. Включайте только если понимаете риск удаления файлов за пределами вашей домашней папки.",
                "DRay will try to move denied files to Trash through a macOS administrator authorization prompt. This does not bypass SIP: macOS system-protected paths remain blocked. Enable only if you understand the risk of deleting files outside your home folder."
            ))
        }
    }

    private var settingsBoard: some View {
        Group {
            if boardColumnCount >= 3 {
                HStack(alignment: .top, spacing: 12) {
                    settingsColumn {
                        permissionsCard
                        recoverySafetyCard
                    }
                    settingsColumn {
                        scanningCleanupCard
                        diagnosticsCard
                    }
                    settingsColumn {
                        generalGroup
                        appearanceGroup
                    }
                }
            } else if boardColumnCount == 2 {
                HStack(alignment: .top, spacing: 12) {
                    settingsColumn {
                        permissionsCard
                        scanningCleanupCard
                        diagnosticsCard
                    }
                    settingsColumn {
                        generalGroup
                        appearanceGroup
                        recoverySafetyCard
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    generalGroup
                    appearanceGroup
                    permissionsCard
                    scanningCleanupCard
                    recoverySafetyCard
                    diagnosticsCard
                }
            }
        }
    }

    private func settingsColumn<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var boardWidthProbe: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    updateBoardWidth(proxy.size.width)
                }
                .onChange(of: proxy.size.width) {
                    updateBoardWidth(proxy.size.width)
                }
        }
    }

    private var boardColumnCount: Int {
        if boardWidth >= 1_320 { return 3 }
        if boardWidth >= 840 { return 2 }
        return 1
    }

    private func updateBoardWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        if abs(boardWidth - width) > 0.5 {
            boardWidth = width
        }
    }
}
