# ADR 0001: Menu-bar hide mechanism — bounded length-inflation, macOS 26 target

- Status: Accepted
- Date: 2026-07-04
- Relates to: docs/specs/0001-menu-bar-hide-show-toggle.md, docs/specs/0003-always-hidden-section.md

## Context
PeekBar hides menu-bar icons the way the reference project (dwarvesf/hidden) does: it owns an expandable separator `NSStatusItem` and, to collapse, inflates that item's width so the icons to its left are pushed off the visible edge of the menu bar. macOS owns cross-app icon ordering, so there is no API to move or hide other apps' items directly; width inflation is the only lever.

Two problems surfaced while researching current macOS:
- On macOS 26 Tahoe, the historical hardcoded width (10000px) triggers pathological menu-bar layout/repaint and multi-GB memory growth (dwarvesf/hidden issue #343, fixed in PR #344 by bounding the width).
- On macOS 27, the menu bar was re-architected: a system `MenuBarAgent` owns layout/compositing and length inflation is ignored — the API "succeeds" and reports the requested width, but items are not actually hidden (dwarvesf/hidden issue #366, PR #358). A managed-overflow / second-bar model (capture items, render them in a separate panel — the Bartender/Ice approach) is required there.

The product spec targets "macOS 26 Tahoe+", so the "+" nominally includes macOS 27.

## Decision
- Use **bounded length-inflation** as the hide mechanism: the collapse width is derived from the current screen width plus a small padding and capped, never a fixed 10000.
- Target **macOS 26 Tahoe** as the supported platform for this mechanism.
- Put the mechanism behind a `HideStrategy` abstraction so an alternative backend can be added without touching the status-bar/toggle/UI layers.
- Treat **macOS 27 as a documented known limitation** and future work, not part of the current scope.

## Alternatives considered
- **Managed-overflow / second-bar now** (capture hidden items via accessibility bounds, render in a dedicated panel, forward clicks). Works on macOS 26 and 27 and is future-proof, but is a substantially larger engineering effort and changes the reveal UX (revealed items appear in a panel rather than in the menu bar). Rejected for the initial scope; revisit when macOS 27 support is prioritized.
- **Lock the minimum target to macOS 26 only** (drop the "+"). Simpler mentally, but the app would visibly break on user upgrades to macOS 27 with no seam to fix it. The abstraction below is the middle ground.

## Consequences
- Hiding works reliably on macOS 26 with bounded memory.
- On macOS 27 the hide will not take effect; this must be surfaced as a known limitation and tracked as future work (a managed-overflow `HideStrategy`).
- The `HideStrategy` seam localizes the future work: adding a managed-overflow backend should not require changes to the toggle, menu, settings, or persistence layers.
