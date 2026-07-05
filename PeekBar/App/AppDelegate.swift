import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var settingsController = SettingsWindowController(settings: settings)
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ApplicationIcon.register()
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

}

@MainActor
enum ApplicationIcon {
    static func register() {
        guard let icon = load() else {
            return
        }

        NSApp.applicationIconImage = icon
    }

    static func aboutPanelOptions() -> [NSApplication.AboutPanelOptionKey: Any] {
        if let icon = NSApp.applicationIconImage {
            return [.applicationIcon: icon]
        }

        if let icon = load() {
            return [.applicationIcon: icon]
        }

        return [:]
    }

    private static func load() -> NSImage? {
        if let icon = NSImage(named: NSImage.applicationIconName) {
            return icon
        }

        return Bundle.main.image(forResource: "AppIcon")
    }
}
