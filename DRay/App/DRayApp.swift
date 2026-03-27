import SwiftUI
import AppKit

@main
struct DRayApp: App {
    init() {
        AppLogger.telemetry.info("App launched")
    }

    var body: some Scene {
        WindowGroup("DRay") {
            RootView()
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
    }
}
