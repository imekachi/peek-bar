import CoreGraphics

/// Abstracts how menu-bar icons are hidden so toggle/menu/UI never depend on the mechanism.
@MainActor
protocol HideStrategy {
    func apply(collapsed: Bool)
}

/// Pure width computation for length-inflation collapse. Side-effect free and testable.
enum HideWidth {
    /// Multiple of screen width to inflate by. The separator does not sit at the right edge
    /// (the Toggle Icon and clock are to its right), so a full extra screen width of slack is
    /// needed to push the leftmost icon past the left edge. Matches the reference project.
    static let collapseMultiplier: CGFloat = 2

    /// Floor width that still reliably pushes icons off-screen on the smallest common displays.
    static let minimum: CGFloat = 1280

    /// Safety ceiling — comfortably above any real display (in points) but below the historical
    /// 10000 that caused pathological menu-bar repaint and multi-GB memory growth on macOS 26.
    static let cap: CGFloat = 8000

    /// Thin boundary-item width (points) when the bar is expanded / revealed.
    static let expandedWidth: CGFloat = 8

    /// Fallback when `NSScreen` width is unavailable; a wide-display-safe value, never 10000.
    private static let unavailableScreenFallback: CGFloat = 3456

    static func collapsedWidth(screenWidth: CGFloat) -> CGFloat {
        guard screenWidth.isFinite, screenWidth > 0 else {
            return bounded(unavailableScreenFallback)
        }
        return bounded(screenWidth * collapseMultiplier)
    }

    static func length(collapsed: Bool, screenWidth: CGFloat) -> CGFloat {
        collapsed ? collapsedWidth(screenWidth: screenWidth) : expandedWidth
    }

    private static func bounded(_ width: CGFloat) -> CGFloat {
        min(max(width, minimum), cap)
    }
}
