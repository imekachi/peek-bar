# PeekBar — Domain Context

Shared domain glossary for all PeekBar specs. These are the canonical terms; every spec references them instead of redefining.

**PeekBar** — The macOS menu-bar utility this project builds. A background "agent" app: no Dock icon, no main application window; it lives only in the menu bar and hides/reveals menu-bar items to declutter the bar.

**Menu-bar item** — Any status item in the macOS system menu bar (PeekBar's own icons or other apps' icons).

**Toggle Icon** — PeekBar's primary menu-bar item. Shown as `›` when expanded (managed items visible) and `‹` when collapsed (managed items hidden). Clicking it toggles collapse/expand. It has a fixed width and is never inflated, so it is never hidden by any PeekBar mechanism, regardless of its position.

**Primary Separator** — PeekBar's solid vertical-line menu-bar item, placed immediately to the left of the Toggle Icon. It marks the right boundary of the Normal-collapse zone and is the item PeekBar inflates to hide that zone. Always present. Because length-inflation pushes the inflating item's own glyph off-screen, this must be a separate item from the Toggle Icon (see docs/adr/0002-two-status-items-minimum.md).

**Secondary Separator** — PeekBar's optional second separator, a **semi-translucent, dashed** vertical line. Present only when the always-hidden feature is enabled. Marks the boundary of the Always-hidden zone; its dashed, translucent styling distinguishes it from the solid Primary Separator.

**Normal-collapse zone** — The menu-bar items to the left of the Primary Separator and to the right of the Secondary Separator (when the always-hidden feature is enabled). When no Secondary Separator exists, it is all items to the left of the Primary Separator. These are shown/hidden by clicking the Toggle Icon.

**Always-hidden zone** — The menu-bar items to the left of the Secondary Separator, excluding the Toggle Icon. Kept hidden at all times unless the user turns on "Show Always Hidden Icons". Rule: everything to the left of the Secondary Separator is treated as always-hidden except the Toggle Icon, which is never hidden — even if the user drags the Secondary Separator to the right of `›`, or makes it the leftmost item.

**Collapse / Expand** — Collapse = hide the Normal-collapse zone (Toggle Icon shows `‹`). Expand = reveal it (Toggle Icon shows `›`).

**Show Always Hidden Icons / Hide Always Hidden Icons** — The right-click-menu action that reveals or re-hides the Always-hidden zone. The label reflects the next action.

**⌘-drag arrange** — The macOS gesture of holding ⌘ and dragging menu-bar items to reorder them. Users position PeekBar's separators and their other icons relative to the zones this way. PeekBar cannot move other apps' icons programmatically; the user arranges them.

**Default layout** — Left → right: `[always-hidden items]  ┊  [normal-collapse items]  │  ›`, where `┊` is the (dashed) Secondary Separator and `│` is the (solid) Primary Separator. The Secondary Separator is present only when the always-hidden feature is enabled. User-adjustable via ⌘-drag.
