# Menu-bar Hide/Show Toggle
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
macOS menu bars get cluttered with icons. Users want a one-click way to hide the icons they don't need at a glance and reveal them on demand, without removing the apps. PeekBar provides this as a lightweight menu-bar utility. This spec covers the foundational app shell and the core hide/show behavior that every other feature builds on.

## Goals
- Ship a menu-bar-only macOS utility (PeekBar) with a single Toggle Icon.
- Let users hide/reveal a contiguous set of menu-bar items with one click.
- Let users choose which items are hidden by arranging icons with ⌘-drag.
- Persist layout and collapsed/expanded state across launches and reboots.
- Provide a right-click menu to reach app actions.

## Non-goals (out of scope)
- Always-hidden section (see 0003).
- Auto-collapse timer (see 0004).
- Launch at login (see 0005).
- Settings window internals (see 0002).
- In-app updates (see 0007).
- App Store distribution.
- Programmatically moving other apps' menu-bar items (macOS does not allow it; users arrange via ⌘-drag).
- A global keyboard shortcut (explicitly dropped).
- macOS 27 support for the hide mechanism: the system's menu-bar re-architecture ignores width inflation, so hiding does not take effect there. Tracked as a known limitation and future work (see docs/adr/0001-menu-bar-hide-mechanism.md).

## Behavior / Requirements
- PeekBar runs as a background agent: no Dock icon, no main application window, presence only in the menu bar.
- On launch, PeekBar shows the Toggle Icon as `›` (expanded), with the Primary Separator (a solid vertical line) immediately to its left.
- Clicking the Toggle Icon collapses the Normal-collapse zone (the items to the left of the Primary Separator): PeekBar inflates the Primary Separator so those items are pushed off the visible edge, and the Toggle Icon changes to `‹`.
- Clicking the Toggle Icon again expands: the Primary Separator returns to its thin width, the hidden items reappear, and the icon returns to `›`.
- Users choose which items are hidden by ⌘-dragging menu-bar icons so the ones they want hidden sit to the left of the Primary Separator (i.e., left of the Toggle Icon, which the Primary Separator sits just left of).
- The Toggle Icon is never hidden or inflated by any PeekBar mechanism. It is a separate status item from the Primary Separator that inflates — a single-item toggle is not achievable with length-inflation (see docs/adr/0002-two-status-items-minimum.md).
- If the Primary Separator is ⌘-dragged to the right of the Toggle Icon, collapse is refused (inflating it there would push the Toggle Icon off-screen).
- The current collapsed/expanded state and the item positions persist across app relaunch and system reboot.
- Right-clicking the Toggle Icon opens the app menu, with items grouped by separators:
  - Group 1: "Show Always Hidden Icons" / "Hide Always Hidden Icons" — shown only when the always-hidden feature is enabled (see 0003).
  - Group 2: "Settings", "Check for updates…", "About".
  - Group 3: "Quit".
  - Menu labels carry no app-name suffix (e.g., "Quit", not "Quit PeekBar").
  - Every menu item shows a leading glyph: SF Symbols (template, 13pt) for all actions including About (`info.circle`) and Quit (`xmark.rectangle`). Do not use the application icon on menu rows.
- "Settings" opens the Settings window (see 0002).
- "About" shows basic app info (name and version; version detail per 0007).
- "Quit" terminates PeekBar and removes its menu-bar icons.

## Domain terms
See docs/specs/CONTEXT.md. Uses: PeekBar, Toggle Icon, Primary Separator, Normal-collapse zone, Collapse / Expand, ⌘-drag arrange, Menu-bar item.

## Decisions
- Minimum supported macOS: 26 Tahoe. Rationale: target only current macOS to use modern system APIs without legacy fallbacks; older macOS is unsupported.
- Distribution is outside the App Store (direct download via GitHub Releases; see 0007). App Store submission is a non-goal.
- No global keyboard shortcut: deliberately dropped to keep scope and required permissions minimal; toggling is via click (and auto-collapse, see 0004).
- At least two status items are required — the Toggle Icon plus a separate Primary Separator that inflates. A true single-item toggle is not achievable with length-inflation and is recorded as an unattainable ideal (see docs/adr/0002-two-status-items-minimum.md).
- Glyphs are rendered by PeekBar, not vendored from the reference project: the Toggle Icon chevron and the Primary Separator are custom-drawn template glyphs (NSBezierPath). The chevron is a 90° angle (~1.8pt stroke, ~11pt arm height); the Primary Separator is a solid vertical line sharing the same stroke width and height for visual consistency. Custom drawing was chosen over SF Symbols to get a precise 90° chevron angle and a specific stroke weight while keeping both glyphs visually aligned (the Secondary Separator, a semi-translucent dashed line, is defined in 0003). The application icon is designed fresh (see 0008).
- Hiding uses bounded width-inflation of an owned separator item (not a fixed 10000px), behind a swappable mechanism abstraction; macOS 27 support is deferred (see docs/adr/0001-menu-bar-hide-mechanism.md).
