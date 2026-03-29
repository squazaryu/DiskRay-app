import SwiftUI
import AppKit

@main
struct DRayApp: App {
    @StateObject private var model = RootViewModel()

    init() {
        AppLogger.telemetry.info("App launched")
    }

    var body: some Scene {
        WindowGroup("DRay") {
            RootView(model: model)
                .frame(minWidth: 1024, minHeight: 680)
                .onAppear {
                    AppLogger.telemetry.info("Root view appeared")
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DRay") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                    AppLogger.telemetry.info("About panel opened")
                }
            }
        }

        MenuBarExtra {
            MenuBarPopupView(model: model)
        } label: {
            MenuBarStatusIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "circle.grid.2x2.fill")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .accessibilityLabel("DRay")
    }
}
