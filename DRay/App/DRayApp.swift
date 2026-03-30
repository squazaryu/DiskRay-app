import SwiftUI
import AppKit

@MainActor
final class AppTerminationCoordinator {
    static let shared = AppTerminationCoordinator()
    private(set) var allowTermination = false

    func closeToMenuBar() {
        NSApp.windows.forEach { window in
            if window.isVisible {
                window.orderOut(nil)
            }
        }
        AppLogger.telemetry.info("Main windows closed to menu bar")
    }

    func terminateCompletely() {
        allowTermination = true
        NSApp.terminate(nil)
    }
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppTerminationCoordinator.shared.allowTermination {
            return .terminateNow
        }
        AppTerminationCoordinator.shared.closeToMenuBar()
        return .terminateCancel
    }
}

@main
struct DRayApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
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
            CommandGroup(replacing: .appTermination) {
                Button("Quit DRay (Keep Menu Bar)") {
                    AppTerminationCoordinator.shared.closeToMenuBar()
                }
                .keyboardShortcut("q")

                Divider()

                Button("Quit DRay Completely", role: .destructive) {
                    AppTerminationCoordinator.shared.terminateCompletely()
                }
            }
            CommandMenu("DRay") {
                Button("Hide Main Window") {
                    NSApp.keyWindow?.orderOut(nil)
                }
                .keyboardShortcut("w")

                Button("Show Main Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }

                Divider()

                Button("Quit DRay Completely", role: .destructive) {
                    AppTerminationCoordinator.shared.terminateCompletely()
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
