import AppKit

/// Hides menu-bar icons by inflating an owned separator `NSStatusItem` width (ADR 0001).
@MainActor
final class LengthInflationStrategy: HideStrategy {
    private let separatorItem: NSStatusItem

    init(separatorItem: NSStatusItem) {
        self.separatorItem = separatorItem
    }

    func apply(collapsed: Bool) {
        let screenWidth = NSScreen.main?.frame.width ?? 0
        separatorItem.length = HideWidth.length(collapsed: collapsed, screenWidth: screenWidth)
    }
}
