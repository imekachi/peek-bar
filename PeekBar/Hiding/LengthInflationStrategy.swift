import AppKit

/// Hides menu-bar icons by inflating an owned separator `NSStatusItem` width (ADR 0001).
@MainActor
final class LengthInflationStrategy: HideStrategy {
    private let separatorItem: NSStatusItem
    private let toggleItem: NSStatusItem

    init(separatorItem: NSStatusItem, toggleItem: NSStatusItem) {
        self.separatorItem = separatorItem
        self.toggleItem = toggleItem
    }

    func apply(collapsed: Bool) {
        if !collapsed {
            separatorItem.length = HideWidth.expandedWidth
            return
        }

        if let separatorFrame = separatorItem.button?.window?.frame,
           let toggleFrame = toggleItem.button?.window?.frame,
           separatorFrame.width > 0,
           toggleFrame.width > 0,
           toggleFrame.minX < separatorFrame.minX {
            separatorItem.length = HideWidth.expandedWidth
            StartupLog.emit("PeekBar: warning — collapse skipped to keep Toggle Icon visible")
            return
        }

        let screenWidth = NSScreen.main?.frame.width ?? 0
        separatorItem.length = HideWidth.length(collapsed: true, screenWidth: screenWidth)
    }
}
