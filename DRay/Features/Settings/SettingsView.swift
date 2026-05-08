import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: RootViewModel
    let onChooseFolder: () -> Void
    @State var showExperimentalElevatedDeletionConsent = false

    var body: some View {
        VStack(spacing: 12) {
            ModuleHeaderCard(
                title: model.localized(.settingsTitle),
                subtitle: model.localized(.settingsSubtitle)
            ) {
                Button(model.localized(.settingsRefresh)) {
                    model.refreshPermissions()
                    model.refreshLaunchAtLoginStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 12) {
                    generalGroup
                    appearanceGroup
                    permissionsCard
                    scanningCleanupCard
                    recoverySafetyCard
                    diagnosticsCard
                }
                .padding(.horizontal, 2)

                settingsStatusStrip
                    .padding(.top, 12)
                    .padding(.horizontal, 2)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .onAppear {
            model.refreshPermissions()
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

    private var settingsColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 360, maximum: 620), spacing: 12, alignment: .top)
        ]
    }
}
