# ADR 0002: Two status items minimum — the single Toggle Icon is an implementation limitation

- Status: Accepted
- Date: 2026-07-04
- Relates to: docs/specs/0001-menu-bar-hide-show-toggle.md, docs/specs/0003-always-hidden-section.md, docs/adr/0001-menu-bar-hide-mechanism.md

## Context
The ideal UX for spec 0001 is a **single** Toggle Icon: everything to its left hides on click, and the Toggle Icon itself is never hidden. We tried to build exactly that and it is not achievable with the chosen hide mechanism.

The hide mechanism (ADR 0001) is bounded length-inflation: one `NSStatusItem` is made very wide so the items to its left fall off the visible edge of the menu bar. The unavoidable side effect is that the **inflating item's own content is pushed off-screen with it**. Status items are laid out right-to-left; when an item's `length` grows, its right edge stays anchored and its left edge (and centered glyph) slides off-screen to the left.

Consequently, if the Toggle Icon is the item that inflates, the Toggle Icon's own glyph slides off-screen on collapse — the toggle disappears and there is no on-screen control to expand again. That is an unrecoverable state and a direct violation of the spec invariant "the Toggle Icon is never hidden".

Two attempts to keep a single visible item failed:
- **Single item, glyph pinned to the right edge.** The chevron was placed in a right-pinned subview so it would stay at the item's anchored right edge while the item inflated leftward. In practice the pinned glyph did not reliably remain on-screen and clickable once the item was inflated; the toggle vanished and the app got stuck collapsed.
- **Invisible boundary item glued to the Toggle Icon's left.** A zero-content anchor item is a phantom the user cannot see, can still ⌘-drag off the bar, and — because macOS persists that removal system-side (not in the app's own defaults) — cannot be reliably restored from within the app. Dragging it off removed the UI with no recovery.

## Decision
- Hiding requires **at least two** status items:
  1. **Toggle Icon** — fixed width, **never inflated**, so it is always on-screen and clickable, and therefore never hidden.
  2. **Primary Separator** — a **solid** vertical line placed immediately to the Toggle Icon's left. This is the item that inflates to hide the Normal-collapse zone.
- When the always-hidden feature (spec 0003) is enabled, a **third** item — the **Secondary Separator** (a semi-translucent, dashed vertical line) — bounds the Always-hidden zone.
- Record the single-Toggle-Icon design as an unattainable ideal. A visible boundary separator is a required element of the UI, not an optional decoration.
- This ADR concerns **item topology only**. The hide mechanism and the `HideStrategy` seam from ADR 0001 are unchanged; the Primary/Secondary Separators are the concrete items a length-inflation `HideStrategy` operates on.

## Alternatives considered
- **Single item, right-pinned glyph.** Rejected: the glyph did not stay reliably visible/clickable when the item inflated, leaving the toggle unreachable.
- **Invisible boundary item.** Rejected: a phantom the user can drag off the bar; its removal persists system-side and is not app-recoverable.
- **Managed-overflow / second-bar** (capture items, render them in a dedicated panel — the Bartender/Ice approach). This removes the boundary marker entirely and would allow a true single-toggle UX, and it works on both macOS 26 and 27. Deferred per ADR 0001: large scope, requires Accessibility (and realistically Screen Recording) permissions, and changes the reveal UX. It can be added later behind the existing `HideStrategy` seam without touching the toggle/menu/settings/persistence layers.

## Consequences
- A visible boundary marker (the solid Primary Separator) is always present next to the Toggle Icon; users arrange icons relative to it via ⌘-drag.
- The Toggle Icon is never inflated and never hidden, so the app is always recoverable.
- The topology matches the reference project (dwarvesf/hidden): a persistent toggle plus one or two inflating separators.
- Spec 0001 and the domain glossary are updated to describe the Primary Separator; spec 0003 refines the Secondary Separator's appearance (semi-translucent, dashed) so the two boundaries are visually distinct.
