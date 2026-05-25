import SwiftUI

@main
struct ClipstasherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipStore = ClipStore.shared

    init() {
        // Eagerly initialize the clipboard monitor so polling starts before the popover opens
        _ = ClipboardMonitor.shared
    }

    var body: some Scene {
        MenuBarExtra("Clipstasher", image: "MenuBarIcon") {
            ClipstasherView()
                .environmentObject(clipStore)
                .environmentObject(appDelegate)
        }
        .menuBarExtraStyle(.window)
    }
}
