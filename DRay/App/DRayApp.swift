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

        MenuBarExtra("DRay", systemImage: "circle.grid.3x3.fill") {
            MenuBarPopupView(model: model)
        }
    }
}
