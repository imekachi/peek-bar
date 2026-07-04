import AppKit

/// Owns the Toggle Icon and expandable separator status items; drives collapse/expand via `HideStrategy`.
@MainActor
final class StatusBarController: NSObject {
  private var settings: SettingsStore
  private let hideStrategy: HideStrategy
  private let toggleItem: NSStatusItem
  private let contextMenu: NSMenu
  private let menuTarget: NSObject

  var isCollapsed: Bool { settings.isCollapsed }

  init(settings: SettingsStore, preferencesController: PreferencesWindowController) {
    self.settings = settings

    // Toggle Icon first so it sits rightmost (nearest the clock); separator is to its left.
    let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    toggleItem.autosaveName = SettingsStore.StatusItemAutosaveName.toggleItem
    self.toggleItem = toggleItem

    let separatorItem = NSStatusBar.system.statusItem(withLength: HideWidth.expandedWidth)
    separatorItem.autosaveName = SettingsStore.StatusItemAutosaveName.separatorItem
    self.hideStrategy = LengthInflationStrategy(separatorItem: separatorItem, toggleItem: toggleItem)

    let menuBundle = StatusItemMenu.makeMenu(preferencesController: preferencesController)
    self.contextMenu = menuBundle.menu
    self.menuTarget = menuBundle.target

    super.init()

    configureToggleButton()

    let collapsed = settings.isCollapsed
    updateChevron(collapsed: collapsed)
    hideStrategy.apply(collapsed: collapsed)

    StartupLog.emit("PeekBar: status item ready")
  }

  func toggle() {
    settings.isCollapsed = !settings.isCollapsed
    let collapsed = settings.isCollapsed
    hideStrategy.apply(collapsed: collapsed)
    updateChevron(collapsed: collapsed)
  }

  #if DEBUG
  func runSelfTestIfRequested() {
    guard ProcessInfo.processInfo.arguments.contains("--selftest") else { return }

    toggle()
    StartupLog.emit("PeekBar: selftest toggle -> collapsed")
    toggle()
    StartupLog.emit("PeekBar: selftest toggle -> expanded")
    StartupLog.emit("PeekBar: selftest done isCollapsed=\(isCollapsed)")
  }
  #endif

  private func configureToggleButton() {
    guard let button = toggleItem.button else {
      StartupLog.emit("PeekBar: warning — toggle status item has no button")
      return
    }

    button.target = self
    button.action = #selector(handleToggleClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  @objc private func handleToggleClick(_ sender: Any?) {
    guard let event = NSApp.currentEvent else { return }

    let isRightClick = event.type == .rightMouseUp
      || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

    if isRightClick {
      presentContextMenu()
    } else {
      toggle()
    }
  }

  private func presentContextMenu() {
    guard let button = toggleItem.button else { return }
    contextMenu.popUp(
      positioning: nil,
      at: NSPoint(x: 0, y: button.bounds.height),
      in: button
    )
  }

  private func updateChevron(collapsed: Bool) {
    guard let button = toggleItem.button else { return }
    button.image = Self.chevronImage(collapsed: collapsed)
  }

  private static func chevronImage(collapsed: Bool) -> NSImage? {
    let symbolName = collapsed ? "chevron.compact.left" : "chevron.compact.right"
    let description = collapsed ? "Expand menu bar icons" : "Collapse menu bar icons"
    guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) else {
      return nil
    }
    image.isTemplate = true
    return image
  }
}
