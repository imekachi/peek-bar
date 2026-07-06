import AppKit

/// Builds the Toggle Icon right-click menu with native `NSMenu` items and separators.
@MainActor
enum StatusItemMenu {
  private enum MenuGlyph {
    static func symbol(_ name: String, accessibilityDescription: String) -> NSImage? {
      let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      guard let base = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) else {
        return nil
      }
      let image = base.withSymbolConfiguration(configuration) ?? base
      image.isTemplate = true
      return image
    }

    static let settings = symbol("gearshape", accessibilityDescription: "Settings")
    static let checkForUpdates = symbol("arrow.down.circle", accessibilityDescription: "Check for updates")
    static let about = symbol("info.circle", accessibilityDescription: "About")
    static let quit = symbol("xmark.rectangle", accessibilityDescription: "Quit")
    static let showAlwaysHidden = symbol("eye", accessibilityDescription: "Show Always Hidden Icons")
    static let hideAlwaysHidden = symbol("eye.slash", accessibilityDescription: "Hide Always Hidden Icons")
  }

  static func makeMenu(
    settings: SettingsStore,
    revealAlwaysHidden: (@MainActor () -> Void)? = nil,
    hideAlwaysHidden: (@MainActor () -> Void)? = nil,
    settingsPresenter: SettingsPresenting,
    manualUpdateChecker: ManualUpdateChecking
  ) -> (menu: NSMenu, target: NSObject) {
    let target = Actions(
      settings: settings,
      revealAlwaysHidden: revealAlwaysHidden,
      hideAlwaysHidden: hideAlwaysHidden,
      settingsPresenter: settingsPresenter,
      manualUpdateChecker: manualUpdateChecker
    )
    let menu = NSMenu()

    let alwaysHidden = NSMenuItem(
      title: "Show Always Hidden Icons",
      action: #selector(Actions.toggleAlwaysHidden(_:)),
      keyEquivalent: ""
    )
    alwaysHidden.target = target
    alwaysHidden.image = MenuGlyph.showAlwaysHidden
    menu.addItem(alwaysHidden)

    let alwaysHiddenSeparator = NSMenuItem.separator()
    menu.addItem(alwaysHiddenSeparator)

    // ⌘, is best-effort for an LSUIElement accessory app (no main menu bar); it only works while this menu is key.
    let settings = NSMenuItem(
      title: "Settings",
      action: #selector(Actions.openSettings(_:)),
      keyEquivalent: ","
    )
    settings.target = target
    settings.image = MenuGlyph.settings
    menu.addItem(settings)

    let checkForUpdates = NSMenuItem(
      title: "Check for updates…",
      action: #selector(Actions.checkForUpdates(_:)),
      keyEquivalent: ""
    )
    checkForUpdates.target = target
    checkForUpdates.image = MenuGlyph.checkForUpdates
    menu.addItem(checkForUpdates)

    let about = NSMenuItem(
      title: "About",
      action: #selector(Actions.showAbout(_:)),
      keyEquivalent: ""
    )
    about.target = target
    about.image = MenuGlyph.about
    menu.addItem(about)

    menu.addItem(.separator())

    let quit = NSMenuItem(
      title: "Quit",
      action: #selector(Actions.quit(_:)),
      keyEquivalent: ""
    )
    quit.target = target
    quit.image = MenuGlyph.quit
    menu.addItem(quit)

    target.alwaysHiddenItem = alwaysHidden
    target.alwaysHiddenSeparator = alwaysHiddenSeparator
    menu.delegate = target
    target.refreshAlwaysHiddenMenuItems()

    return (menu, target)
  }

  @MainActor
  private final class Actions: NSObject, NSMenuDelegate {
    private let settings: SettingsStore
    private let revealAlwaysHidden: (@MainActor () -> Void)?
    private let hideAlwaysHidden: (@MainActor () -> Void)?
    private let settingsPresenter: SettingsPresenting
    private let manualUpdateChecker: ManualUpdateChecking
    fileprivate weak var alwaysHiddenItem: NSMenuItem?
    fileprivate weak var alwaysHiddenSeparator: NSMenuItem?

    init(
      settings: SettingsStore,
      revealAlwaysHidden: (@MainActor () -> Void)?,
      hideAlwaysHidden: (@MainActor () -> Void)?,
      settingsPresenter: SettingsPresenting,
      manualUpdateChecker: ManualUpdateChecking
    ) {
      self.settings = settings
      self.revealAlwaysHidden = revealAlwaysHidden
      self.hideAlwaysHidden = hideAlwaysHidden
      self.settingsPresenter = settingsPresenter
      self.manualUpdateChecker = manualUpdateChecker
    }

    fileprivate func refreshAlwaysHiddenMenuItems() {
      let isEnabled = settings.alwaysHiddenEnabled
      alwaysHiddenItem?.isHidden = !isEnabled
      alwaysHiddenSeparator?.isHidden = !isEnabled
      alwaysHiddenItem?.title = settings.isAlwaysHiddenRevealed
        ? "Hide Always Hidden Icons"
        : "Show Always Hidden Icons"
      alwaysHiddenItem?.image = settings.isAlwaysHiddenRevealed
        ? MenuGlyph.hideAlwaysHidden
        : MenuGlyph.showAlwaysHidden
    }

    func menuWillOpen(_ menu: NSMenu) {
      refreshAlwaysHiddenMenuItems()
    }

    @objc func toggleAlwaysHidden(_ sender: Any?) {
      guard settings.alwaysHiddenEnabled else { return }

      if settings.isAlwaysHiddenRevealed {
        if let hideAlwaysHidden {
          hideAlwaysHidden()
        } else {
          settings.isAlwaysHiddenRevealed = false
        }
      } else {
        if let revealAlwaysHidden {
          revealAlwaysHidden()
        } else {
          settings.isAlwaysHiddenRevealed = true
        }
      }
      refreshAlwaysHiddenMenuItems()
    }

    @objc func openSettings(_ sender: Any?) {
      settingsPresenter.show()
    }

    @objc func checkForUpdates(_ sender: Any?) {
      manualUpdateChecker.checkManually()
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
