import AppKit

typealias HideStrategyFactory = (_ separatorItem: NSStatusItem, _ toggleItem: NSStatusItem) -> HideStrategy

/// Owns two status items: the Toggle Icon (always visible, fixed width, NEVER inflated) and an
/// inflatable boundary item glued to its left. Collapse inflates ONLY the boundary item, pushing
/// icons to its left off-screen; the Toggle Icon never inflates, so it is never hidden (spec 0001).
@MainActor
final class StatusBarController: NSObject {
  private let settings: SettingsStore
  private let hideStrategy: HideStrategy
  private let toggleItem: NSStatusItem
  private let separatorItem: NSStatusItem
  private let contextMenu: NSMenu
  private let menuTarget: NSObject

  var isCollapsed: Bool { settings.isCollapsed }

  init(
    settings: SettingsStore,
    preferencesController: PreferencesWindowController,
    hideStrategyFactory: HideStrategyFactory = { separatorItem, toggleItem in
      LengthInflationStrategy(separatorItem: separatorItem, toggleItem: toggleItem)
    }
  ) {
    self.settings = settings

    // Toggle Icon first so it sits rightmost (nearest the clock). It keeps a fixed width and is
    // never inflated, so it stays visible and clickable in every state.
    let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    toggleItem.autosaveName = SettingsStore.StatusItemAutosaveName.toggleItem
    self.toggleItem = toggleItem

    // Boundary item, created second so it sits to the Toggle Icon's left. This is the item that
    // inflates on collapse; its own glyph slides off-screen while inflated (that is expected).
    let separatorItem = NSStatusBar.system.statusItem(withLength: HideWidth.expandedWidth)
    separatorItem.autosaveName = SettingsStore.StatusItemAutosaveName.separatorItem
    self.separatorItem = separatorItem
    self.hideStrategy = hideStrategyFactory(separatorItem, toggleItem)

    let menuBundle = StatusItemMenu.makeMenu(preferencesController: preferencesController)
    self.contextMenu = menuBundle.menu
    self.menuTarget = menuBundle.target

    super.init()

    configureToggleButton()
    configureSeparator()
    restoreItemVisibility()

    applyCollapsedState(settings.isCollapsed)

    StartupLog.emit("PeekBar: status item ready")
  }

  /// Reset to expanded on quit so hidden icons reappear, without mutating the persisted state.
  func expandForShutdown() {
    _ = hideStrategy.apply(collapsed: false)
  }

  func toggle() {
    applyCollapsedState(!isCollapsed)
  }

  @discardableResult
  private func applyCollapsedState(_ collapsed: Bool) -> Bool {
    let applied = hideStrategy.apply(collapsed: collapsed)
    let actualCollapsed = collapsed && applied
    settings.isCollapsed = actualCollapsed
    updateChevron(collapsed: actualCollapsed)
    return actualCollapsed
  }

  #if DEBUG
  func runSelfTestIfRequested() {
    guard ProcessInfo.processInfo.arguments.contains("--selftest") else { return }

    toggle()
    StartupLog.emit("PeekBar: selftest toggle -> \(isCollapsed ? "collapsed" : "expanded") sep=\(separatorItem.length) toggle=\(toggleItem.length)")
    toggle()
    StartupLog.emit("PeekBar: selftest toggle -> \(isCollapsed ? "collapsed" : "expanded") sep=\(separatorItem.length) toggle=\(toggleItem.length)")
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

  /// Renders the boundary item as a thin vertical line: icons ⌘-dragged to its left are what
  /// collapse hides. Visible so the boundary is discoverable and not a phantom slot.
  private func configureSeparator() {
    guard let button = separatorItem.button else { return }
    button.image = Self.separatorImage()
    button.toolTip = "PeekBar — drag icons to the left of this line to hide them"
  }

  /// ⌘-dragging an item off the bar can persist as removed. The Toggle Icon is the only reliably
  /// reachable UI, so force both items visible at launch as a best-effort self-restore.
  private func restoreItemVisibility() {
    toggleItem.isVisible = true
    separatorItem.isVisible = true
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
    button.setAccessibilityLabel(collapsed ? "Expand menu bar icons" : "Collapse menu bar icons")
  }

  /// A hand-drawn 90° chevron (template). SF Symbol chevrons have a fixed, narrower angle and
  /// `SymbolConfiguration` can't widen it, so the glyph is stroked directly: a right-angle vertex
  /// needs the horizontal reach to equal half the vertical span (width = height / 2).
  /// Shared glyph metrics so the Toggle Icon chevron and the Primary Separator match in stroke
  /// width, height, and (template) color.
  private static let glyphLineWidth: CGFloat = 1.8
  private static let glyphHeight: CGFloat = 11

  private static func chevronImage(collapsed: Bool) -> NSImage {
    let lineWidth = glyphLineWidth
    let armHeight = glyphHeight
    let armWidth = armHeight / 2
    let inset = lineWidth / 2 + 0.5
    let size = NSSize(width: armWidth + inset * 2, height: armHeight + inset * 2)

    let image = NSImage(size: size)
    image.lockFocus()

    let path = NSBezierPath()
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round

    let top = size.height - inset
    let bottom = inset
    let midY = size.height / 2
    let leftX = inset
    let rightX = size.width - inset

    if collapsed {
      // `‹` — vertex on the left (points left / "expand")
      path.move(to: NSPoint(x: rightX, y: top))
      path.line(to: NSPoint(x: leftX, y: midY))
      path.line(to: NSPoint(x: rightX, y: bottom))
    } else {
      // `›` — vertex on the right (points right / "collapse")
      path.move(to: NSPoint(x: leftX, y: top))
      path.line(to: NSPoint(x: rightX, y: midY))
      path.line(to: NSPoint(x: leftX, y: bottom))
    }

    NSColor.black.setStroke()
    path.stroke()

    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  /// A vertical line (template) marking the collapse boundary — same stroke width, height, and
  /// menu-bar tint as the Toggle Icon chevron.
  private static func separatorImage() -> NSImage {
    let lineWidth = glyphLineWidth
    let inset = lineWidth / 2 + 0.5
    let size = NSSize(width: lineWidth + inset * 2, height: glyphHeight + inset * 2)

    let image = NSImage(size: size)
    image.lockFocus()

    let path = NSBezierPath()
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    let x = size.width / 2
    path.move(to: NSPoint(x: x, y: inset))
    path.line(to: NSPoint(x: x, y: size.height - inset))

    NSColor.black.setStroke()
    path.stroke()

    image.unlockFocus()
    image.isTemplate = true
    return image
  }
}
