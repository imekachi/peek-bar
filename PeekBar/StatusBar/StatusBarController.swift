import AppKit
import Combine

typealias HideStrategyFactory = (_ separatorItem: NSStatusItem, _ toggleItem: NSStatusItem) -> HideStrategy

/// Owns PeekBar's menu-bar items: the Toggle Icon (always visible, fixed width, NEVER inflated),
/// the solid Primary Separator, and the optional dashed Secondary Separator (specs 0001/0003).
@MainActor
final class StatusBarController: NSObject {
  private let settings: SettingsStore
  private let hideStrategy: HideStrategy
  private let alwaysHiddenStrategy: HideStrategy
  private let toggleItem: NSStatusItem
  private let separatorItem: NSStatusItem
  private let secondarySeparatorItem: NSStatusItem
  private var contextMenu: NSMenu!
  private var menuTarget: NSObject!
  private var settingsObservers = Set<AnyCancellable>()

  var isCollapsed: Bool { settings.isCollapsed }

  init(
    settings: SettingsStore,
    settingsController: SettingsWindowController,
    manualUpdateChecker: ManualUpdateChecking,
    hideStrategyFactory: HideStrategyFactory = { separatorItem, toggleItem in
      LengthInflationStrategy(separatorItem: separatorItem, toggleItem: toggleItem)
    }
  ) {
    self.settings = settings

    // User-arranged Toggle Icon. It keeps a fixed width and is never inflated directly.
    let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    toggleItem.autosaveName = SettingsStore.StatusItemAutosaveName.toggleItem
    self.toggleItem = toggleItem

    // Boundary item, created second so it sits to the Toggle Icon's left. This is the item that
    // inflates on collapse; its own glyph slides off-screen while inflated (that is expected).
    let separatorItem = NSStatusBar.system.statusItem(withLength: HideWidth.expandedWidth)
    separatorItem.autosaveName = SettingsStore.StatusItemAutosaveName.separatorItem
    self.separatorItem = separatorItem
    self.hideStrategy = hideStrategyFactory(separatorItem, toggleItem)

    // Created third so the default layout is:
    // [always-hidden items] [Secondary Separator] [normal-collapse items] [Primary Separator] [Toggle Icon].
    let secondarySeparatorItem = NSStatusBar.system.statusItem(withLength: HideWidth.expandedWidth)
    secondarySeparatorItem.autosaveName = SettingsStore.StatusItemAutosaveName.secondarySeparatorItem
    self.secondarySeparatorItem = secondarySeparatorItem
    self.alwaysHiddenStrategy = hideStrategyFactory(secondarySeparatorItem, toggleItem)

    super.init()

    let menuBundle = StatusItemMenu.makeMenu(
      settings: settings,
      revealAlwaysHidden: { [weak self] in
        self?.revealAlwaysHidden()
      },
      hideAlwaysHidden: { [weak self] in
        self?.hideAlwaysHidden()
      },
      settingsPresenter: settingsController,
      manualUpdateChecker: manualUpdateChecker
    )
    contextMenu = menuBundle.menu
    menuTarget = menuBundle.target

    configureToggleButton(toggleItem)
    configureSeparator(
      separatorItem,
      style: .solid,
      toolTip: "PeekBar — drag icons to the left of this line to hide them"
    )
    configureSeparator(
      secondarySeparatorItem,
      style: .secondaryDashed,
      toolTip: "PeekBar — drag rarely used icons to the left of this dashed line to always hide them"
    )
    restoreItemVisibility()
    observeSettings()

    applyAlwaysHiddenState()
    applyCollapsedState(settings.isCollapsed)

    StartupLog.emit("PeekBar: status item ready")
  }

  /// Reset to expanded on quit so hidden icons reappear, without mutating the persisted state.
  func expandForShutdown() {
    _ = alwaysHiddenStrategy.apply(collapsed: false)
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
    if actualCollapsed {
      AlwaysHiddenVisibilityState.markHiddenByNormalCollapse(settings: settings)
    }
    updateChevron(collapsed: actualCollapsed)
    return actualCollapsed
  }

  private func revealAlwaysHidden() {
    AlwaysHiddenVisibilityState.reveal(settings: settings) { [weak self] in
      self?.applyCollapsedState(false)
    }
    applyAlwaysHiddenState()
  }

  private func hideAlwaysHidden() {
    settings.isAlwaysHiddenRevealed = false
    applyAlwaysHiddenState()
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

  private func configureToggleButton(_ item: NSStatusItem) {
    guard let button = item.button else {
      StartupLog.emit("PeekBar: warning — toggle status item has no button")
      return
    }

    button.target = self
    button.action = #selector(handleToggleClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  /// Renders a visible boundary marker. The glyph view is pinned to the trailing edge so it stays
  /// visible while the status item inflates leftward to hide icons.
  @discardableResult
  private func configureSeparator(
    _ item: NSStatusItem,
    style: SeparatorGlyphView.Style,
    toolTip: String
  ) -> SeparatorGlyphView? {
    guard let button = item.button else { return nil }
    button.image = nil
    button.toolTip = toolTip

    let glyphView = SeparatorGlyphView(style: style)
    glyphView.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(glyphView)

    NSLayoutConstraint.activate([
      glyphView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
      glyphView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
      glyphView.widthAnchor.constraint(equalToConstant: HideWidth.expandedWidth),
      glyphView.heightAnchor.constraint(equalToConstant: Self.glyphHeight + Self.glyphLineWidth + 1),
    ])

    return glyphView
  }

  /// ⌘-dragging an item off the bar can persist as removed. The Toggle Icon is the only reliably
  /// reachable UI, so force PeekBar's active items visible at launch as a best-effort self-restore.
  private func restoreItemVisibility() {
    toggleItem.isVisible = true
    separatorItem.isVisible = true
    secondarySeparatorItem.isVisible = settings.alwaysHiddenEnabled
  }

  private func observeSettings() {
    settings.$alwaysHiddenEnabled
      .dropFirst()
      .sink { [weak self] _ in
        Task { @MainActor in
          self?.applyAlwaysHiddenState()
        }
      }
      .store(in: &settingsObservers)

    settings.$isAlwaysHiddenRevealed
      .dropFirst()
      .sink { [weak self] _ in
        Task { @MainActor in
          self?.applyAlwaysHiddenState()
        }
      }
      .store(in: &settingsObservers)
  }

  private func applyAlwaysHiddenState() {
    AlwaysHiddenSectionController.apply(
      settings: settings,
      setSecondarySeparatorVisible: { [secondarySeparatorItem] visible in
        secondarySeparatorItem.isVisible = visible
      },
      applyAlwaysHiddenStrategy: { [alwaysHiddenStrategy] collapsed in
        alwaysHiddenStrategy.apply(collapsed: collapsed)
      },
      expandNormalCollapse: { [weak self] in
        self?.applyCollapsedState(false)
      }
    )
  }

  static func applyAlwaysHiddenStateForTesting(
    settings: SettingsStore,
    setSecondarySeparatorVisible: (Bool) -> Void,
    applyAlwaysHiddenStrategy: (Bool) -> Bool,
    expandNormalCollapse: () -> Void
  ) {
    AlwaysHiddenSectionController.apply(
      settings: settings,
      setSecondarySeparatorVisible: setSecondarySeparatorVisible,
      applyAlwaysHiddenStrategy: applyAlwaysHiddenStrategy,
      expandNormalCollapse: expandNormalCollapse
    )
  }
  @objc private func handleToggleClick(_ sender: Any?) {
    guard let event = NSApp.currentEvent else { return }

    let isRightClick = event.type == .rightMouseUp
      || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

    if isRightClick {
      presentContextMenu(from: sender)
    } else {
      toggle()
    }
  }

  private func presentContextMenu(from sender: Any?) {
    guard let button = (sender as? NSStatusBarButton) ?? toggleItem.button else { return }
    contextMenu.popUp(
      positioning: nil,
      at: NSPoint(x: 0, y: button.bounds.height),
      in: button
    )
  }

  private func updateChevron(collapsed: Bool) {
    updateChevron(for: toggleItem, collapsed: collapsed)
  }

  private func updateChevron(for item: NSStatusItem, collapsed: Bool) {
    guard let button = item.button else { return }
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

}

@MainActor
enum AlwaysHiddenSectionController {
  static func apply(
    settings: SettingsStore,
    setSecondarySeparatorVisible: (Bool) -> Void,
    applyAlwaysHiddenStrategy: (Bool) -> Bool,
    expandNormalCollapse: () -> Void
  ) {
    guard settings.alwaysHiddenEnabled else {
      _ = applyAlwaysHiddenStrategy(false)
      setSecondarySeparatorVisible(false)
      return
    }

    setSecondarySeparatorVisible(true)
    if settings.isAlwaysHiddenRevealed && settings.isCollapsed {
      expandNormalCollapse()
    }

    let shouldHideAlwaysHiddenZone = !settings.isAlwaysHiddenRevealed
    let applied = applyAlwaysHiddenStrategy(shouldHideAlwaysHiddenZone)
    if shouldHideAlwaysHiddenZone && !applied {
      AlwaysHiddenVisibilityState.restoreRevealAfterRefusedHideIfVisible(settings: settings)
    }
  }
}

@MainActor
enum AlwaysHiddenVisibilityState {
  static func reveal(settings: SettingsStore, expandNormalCollapse: () -> Void) {
    if settings.isCollapsed {
      expandNormalCollapse()
    }

    settings.isAlwaysHiddenRevealed = true
  }

  static func markHiddenByNormalCollapse(settings: SettingsStore) {
    settings.isAlwaysHiddenRevealed = false
  }

  static func restoreRevealAfterRefusedHideIfVisible(settings: SettingsStore) {
    if !settings.isCollapsed {
      settings.isAlwaysHiddenRevealed = true
    }
  }
}

private final class SeparatorGlyphView: NSView {
  enum Style {
    case solid
    case secondaryDashed
  }

  private let style: Style

  init(style: Style) {
    self.style = style
    super.init(frame: .zero)
    isHidden = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func draw(_ dirtyRect: NSRect) {
    let path = NSBezierPath()
    path.lineWidth = lineWidth
    path.lineCapStyle = .round

    if case .secondaryDashed = style {
      var pattern = [CGFloat(1.4), CGFloat(2.2)]
      path.setLineDash(&pattern, count: pattern.count, phase: 0)
    }

    let x = bounds.midX
    let inset = lineWidth / 2
    path.move(to: NSPoint(x: x, y: inset))
    path.line(to: NSPoint(x: x, y: bounds.height - inset))

    strokeColor.setStroke()
    path.stroke()
  }

  private var lineWidth: CGFloat {
    switch style {
    case .solid:
      1.8
    case .secondaryDashed:
      1.4
    }
  }

  private var strokeColor: NSColor {
    switch style {
    case .solid:
      .labelColor
    case .secondaryDashed:
      NSColor.labelColor.withAlphaComponent(0.45)
    }
  }
}
