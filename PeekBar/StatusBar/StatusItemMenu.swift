import AppKit

/// Builds the Toggle Icon right-click menu with native `NSMenu` items and separators.
@MainActor
enum StatusItemMenu {
  static func makeMenu(
    preferencesController: PreferencesWindowController
  ) -> (menu: NSMenu, target: NSObject) {
    let target = Actions(preferencesController: preferencesController)
    let menu = NSMenu()

    let preferences = NSMenuItem(
      title: "Preferences",
      action: #selector(Actions.openPreferences(_:)),
      keyEquivalent: ""
    )
    preferences.target = target
    menu.addItem(preferences)

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
    private let preferencesController: PreferencesWindowController

    init(preferencesController: PreferencesWindowController) {
      self.preferencesController = preferencesController
    }

    @objc func openPreferences(_ sender: Any?) {
      preferencesController.show()
    }

    @objc func showAbout(_ sender: Any?) {
      NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func quit(_ sender: Any?) {
      NSApp.terminate(nil)
    }
  }
}
