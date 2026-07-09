import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var updateController = UpdateController(settings: settings)
    private lazy var launchAtLoginController = LaunchAtLoginController(
        settings: settings,
        loginItem: SMAppServiceLoginItem()
    )
    private lazy var settingsController = SettingsWindowController(
        settings: settings,
        manualUpdateChecker: updateController
    )
    private lazy var settingsPresenter = LaunchAtLoginReconcilingSettingsPresenter(
        launchAtLoginController: launchAtLoginController,
        settingsController: settingsController
    )
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ApplicationIcon.register()
        StartupLog.emit("PeekBar: launched")

        let isFirstLaunch = !settings.hasLaunchedBefore
        updateController.start()
        launchAtLoginController.start(isFirstLaunch: isFirstLaunch)

        let statusBar = StatusBarController(
            settings: settings,
            settingsPresenter: settingsPresenter,
            manualUpdateChecker: updateController
        )
        statusBarController = statusBar

        #if DEBUG
        statusBar.runSelfTestIfRequested()
        #endif

        if isFirstLaunch {
            settingsPresenter.show()
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
private final class LaunchAtLoginReconcilingSettingsPresenter: SettingsPresenting {
    private let launchAtLoginController: LaunchAtLoginController
    private let settingsController: SettingsWindowController

    init(
        launchAtLoginController: LaunchAtLoginController,
        settingsController: SettingsWindowController
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.settingsController = settingsController
    }

    func show() {
        launchAtLoginController.reconcile()
        settingsController.show()
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
