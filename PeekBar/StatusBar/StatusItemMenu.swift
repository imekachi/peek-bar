import AppKit

/// Builds the Toggle Icon right-click menu with native `NSMenu` items and separators.
@MainActor
enum StatusItemMenu {
  static func makeMenu(
    settingsController: SettingsWindowController
  ) -> (menu: NSMenu, target: NSObject) {
    let target = Actions(settingsController: settingsController)
    let menu = NSMenu()

    // ⌘, is best-effort for an LSUIElement accessory app (no main menu bar); it only works while this menu is key.
    let settings = NSMenuItem(
      title: "Settings",
      action: #selector(Actions.openSettings(_:)),
      keyEquivalent: ","
    )
    settings.target = target
    menu.addItem(settings)

    let checkForUpdates = NSMenuItem(
      title: "Check for updates…",
      action: nil,
      keyEquivalent: ""
    )
    checkForUpdates.isEnabled = false
    menu.addItem(checkForUpdates)

    let about = NSMenuItem(
      title: "About",
      action: #selector(Actions.showAbout(_:)),
      keyEquivalent: ""
    )
    about.target = target
    menu.addItem(about)

    menu.addItem(.separator())

    let quit = NSMenuItem(
      title: "Quit",
      action: #selector(Actions.quit(_:)),
      keyEquivalent: ""
    )
    quit.target = target
    menu.addItem(quit)

    return (menu, target)
  }

  @MainActor
  private final class Actions: NSObject {
    private let settingsController: SettingsWindowController

    init(settingsController: SettingsWindowController) {
      self.settingsController = settingsController
    }

    @objc func openSettings(_ sender: Any?) {
      settingsController.show()
    }

    @objc func showAbout(_ sender: Any?) {
      // As an .accessory app PeekBar isn't active, so the panel would open behind other
      // windows (or not at all). Activate first, then bring the standard panel to front.
      NSApp.activate(ignoringOtherApps: true)
      NSApp.orderFrontStandardAboutPanel(options: ApplicationIcon.aboutPanelOptions())
    }

    @objc func quit(_ sender: Any?) {
      NSApp.terminate(nil)
    }
  }
}
