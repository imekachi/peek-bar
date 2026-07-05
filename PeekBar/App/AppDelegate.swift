import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var settingsController = SettingsWindowController(settings: settings)
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerApplicationIcon()
        StartupLog.emit("PeekBar: launched")

        let statusBar = StatusBarController(
            settings: settings,
            settingsController: settingsController
        )
        statusBarController = statusBar

        #if DEBUG
        statusBar.runSelfTestIfRequested()
        #endif

        if !settings.hasLaunchedBefore {
            settingsController.show()
            StartupLog.emit("PeekBar: settings auto-opened (first launch)")
            settings.hasLaunchedBefore = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Restore any hidden icons on quit. Removing the status items on exit already reclaims
        // the space, but resetting the separator first guarantees icons reappear immediately.
        statusBarController?.expandForShutdown()
        StartupLog.emit("PeekBar: terminating — icons restored")
    }

    private func registerApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }
}
