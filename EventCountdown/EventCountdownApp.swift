import AppKit
import SwiftUI

@main
struct EventCountdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        CountdownCalculator.demo()
        EventID.demo()
        RefreshPlanner.demo()
        #endif

        // Ensure the store observer is live while the app runs, so editing
        // Calendar reloads the widgets immediately.
        _ = EventStore.shared
    }

    var body: some Scene {
        WindowGroup {
            PermissionView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

/// Quit the app when its window is closed with the red button.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
