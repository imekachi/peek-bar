# PeekBar — Domain Context

Shared domain glossary for all PeekBar specs. These are the canonical terms; every spec references them instead of redefining.

**PeekBar** — The macOS menu-bar utility this project builds. A background "agent" app: no Dock icon, no main application window; it lives only in the menu bar and hides/reveals menu-bar items to declutter the bar.

**Menu-bar item** — Any status item in the macOS system menu bar (PeekBar's own icons or other apps' icons).

**Toggle Icon** — PeekBar's primary menu-bar item. Shown as `›` when expanded (managed items visible) and `‹` when collapsed (managed items hidden). Clicking it toggles collapse/expand. It is never hidden by any PeekBar mechanism, regardless of its position.

**Secondary Separator** — PeekBar's optional second menu-bar item, shown as `ǀ`. Present only when the always-hidden feature is enabled. Defines the boundary of the always-hidden zone.

**Normal-collapse zone** — The menu-bar items to the left of the Toggle Icon and to the right of the Secondary Separator (i.e., between `ǀ` and `›`). When no Secondary Separator exists, it is all items to the left of the Toggle Icon. These are shown/hidden by clicking the Toggle Icon.

**Always-hidden zone** — The menu-bar items to the left of the Secondary Separator (`ǀ`), excluding the Toggle Icon. Kept hidden at all times unless the user turns on "Show Always Hidden Icons". Rule: everything to the left of `ǀ` is treated as always-hidden except the Toggle Icon, which is never hidden — even if the user drags `ǀ` to the right of `›`, or makes `ǀ` the leftmost item.

**Collapse / Expand** — Collapse = hide the Normal-collapse zone (Toggle Icon shows `‹`). Expand = reveal it (Toggle Icon shows `›`).

**Show Always Hidden Icons / Hide Always Hidden Icons** — The right-click-menu action that reveals or re-hides the Always-hidden zone. The label reflects the next action.

**⌘-drag arrange** — The macOS gesture of holding ⌘ and dragging menu-bar items to reorder them. Users position PeekBar's separators and their other icons relative to the zones this way. PeekBar cannot move other apps' icons programmatically; the user arranges them.

**Default layout** — Left → right: `[always-hidden items]  ǀ  [normal-collapse items]  ›`. User-adjustable via ⌘-drag.
