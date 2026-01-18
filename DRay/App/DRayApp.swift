import SwiftUI

@main
struct DRayApp: App {
    var body: some Scene {
        WindowGroup("DRay") {
            RootView()
                .frame(minWidth: 1024, minHeight: 680)
        }
        .windowResizability(.contentSize)
    }
}
