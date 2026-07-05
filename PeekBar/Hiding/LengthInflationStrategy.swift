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

    func apply(collapsed: Bool) -> Bool {
        guard collapsed else {
            separatorItem.length = HideWidth.expandedWidth
            return true
        }

        if shouldRefuseCollapse() {
            separatorItem.length = HideWidth.expandedWidth
            StartupLog.emit("PeekBar: warning — collapse refused; boundary is right of the Toggle Icon")
            return false
        }

        // The menu bar replicates across every attached display, so size the collapse to the
        // WIDEST screen — a narrower one would leak hidden icons on a wider external display.
        let screenWidth = NSScreen.screens.map { $0.frame.width }.max() ?? 0
        separatorItem.length = HideWidth.length(collapsed: true, screenWidth: screenWidth)
        return true
    }

    private func shouldRefuseCollapse() -> Bool {
        guard
            let separatorFrame = separatorItem.button?.window?.frame,
            let toggleFrame = toggleItem.button?.window?.frame
        else {
            return false
        }

        return Self.shouldRefuseCollapse(separatorFrame: separatorFrame, toggleFrame: toggleFrame)
    }

    static func shouldRefuseCollapse(separatorFrame: CGRect, toggleFrame: CGRect) -> Bool {
        guard
            separatorFrame.width > 0,
            toggleFrame.width > 0
        else {
            return false
        }

        // If the boundary sits to the Toggle Icon's right, inflating it would push the Toggle Icon
        // off-screen. Refuse and let callers keep/revert to a truthful revealed state.
        return toggleFrame.minX < separatorFrame.minX
    }
}
