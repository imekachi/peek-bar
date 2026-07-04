import AppKit

/// Hides menu-bar icons by inflating a dedicated boundary `NSStatusItem` (ADR 0001): a wide item
/// pushes every icon to its left off the visible edge. The Toggle Icon is a SEPARATE item that is
/// never inflated here, so it is never hidden. If the boundary is (mis)arranged to the right of the
/// Toggle Icon, inflating would hide the Toggle Icon — so that case is refused.
@MainActor
final class LengthInflationStrategy: HideStrategy {
    private let separatorItem: NSStatusItem
    private let toggleItem: NSStatusItem

    init(separatorItem: NSStatusItem, toggleItem: NSStatusItem) {
        self.separatorItem = separatorItem
        self.toggleItem = toggleItem
    }

    func apply(collapsed: Bool) {
        guard collapsed else {
            separatorItem.length = HideWidth.expandedWidth
            return
        }

        // Never inflate past the Toggle Icon: if the boundary sits to the Toggle Icon's right,
        // inflating it would push the Toggle Icon off-screen. Refuse and leave the bar expanded.
        if let separatorFrame = separatorItem.button?.window?.frame,
           let toggleFrame = toggleItem.button?.window?.frame,
           separatorFrame.width > 0,
           toggleFrame.width > 0,
           toggleFrame.minX < separatorFrame.minX {
            separatorItem.length = HideWidth.expandedWidth
            StartupLog.emit("PeekBar: warning — collapse refused; boundary is right of the Toggle Icon")
            return
        }

        // The menu bar replicates across every attached display, so size the collapse to the
        // WIDEST screen — a narrower one would leak hidden icons on a wider external display.
        let screenWidth = NSScreen.screens.map { $0.frame.width }.max() ?? 0
        separatorItem.length = HideWidth.length(collapsed: true, screenWidth: screenWidth)
    }
}
