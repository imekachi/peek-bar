import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let preferencesController = PreferencesWindowController()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StartupLog.emit("PeekBar: launched")

        let statusBar = StatusBarController(
            settings: settings,
            preferencesController: preferencesController
        )
        statusBarController = statusBar

        #if DEBUG
        statusBar.runSelfTestIfRequested()
        #endif

        if !settings.hasLaunchedBefore {
            preferencesController.show()
            StartupLog.emit("PeekBar: preferences auto-opened (first launch)")
            settings.hasLaunchedBefore = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Restore any hidden icons on quit. Removing the status items on exit already reclaims
        // the space, but resetting the separator first guarantees icons reappear immediately.
        statusBarController?.expandForShutdown()
        StartupLog.emit("PeekBar: terminating — icons restored")
    }
}
