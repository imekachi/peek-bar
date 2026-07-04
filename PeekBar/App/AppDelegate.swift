import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let preferencesController = PreferencesWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StartupLog.emit("PeekBar: launched")

        if !settings.hasLaunchedBefore {
            preferencesController.show()
            StartupLog.emit("PeekBar: preferences auto-opened (first launch)")
            settings.hasLaunchedBefore = true
        }
    }
}
