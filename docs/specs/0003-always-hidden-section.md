# Always-hidden Section
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
Some menu-bar icons are ones the user almost never needs and doesn't want to see even when they reveal their normal hidden set. PeekBar offers an optional "always-hidden" section: a second tier that stays hidden unless explicitly revealed.

## Goals
- Let users keep a set of icons hidden at all times, separate from the normal collapse set.
- Let users reveal that set on demand from the right-click menu, then re-hide it.
- Keep the feature optional and off by default.

## Non-goals (out of scope)
- Core collapse behavior (see 0001).
- Auto-re-hiding the always-hidden set on a timer (this feature is manual reveal/hide only).

## Behavior / Requirements
- The always-hidden feature is disabled by default and enabled via a Preferences toggle (see 0002).
- When disabled, no Secondary Separator appears; only the Toggle Icon and the solid Primary Separator (see 0001) are present.
- When enabled, PeekBar shows the Secondary Separator — a **semi-translucent, dashed** vertical line — in the menu bar. Its dashed, translucent styling makes it visually distinct from the solid Primary Separator, so the always-hidden boundary reads differently from the normal-collapse boundary.
- Items to the left of the Secondary Separator (the Always-hidden zone) are hidden at all times, except the Toggle Icon, which is never hidden.
- Default layout, left → right: `[always-hidden items]  ┊(dashed)  [normal-collapse items]  │(solid)  › `, where `┊` is the Secondary Separator and `│` is the Primary Separator. Positions are user-adjustable via ⌘-drag.
- The positioning rule holds regardless of drag position: everything to the left of the Secondary Separator is treated as always-hidden except the Toggle Icon — even if the Secondary Separator is dragged to the right of `›`, or becomes the leftmost item.
- When the Always-hidden zone is hidden, the right-click menu shows "Show Always Hidden Icons".
- Choosing "Show Always Hidden Icons" reveals the Always-hidden zone; the menu item then reads "Hide Always Hidden Icons".
- Choosing "Hide Always Hidden Icons" re-hides the zone and the label reverts.
- The enabled/disabled state and the current reveal/hide state persist across relaunch.

## Domain terms
See docs/specs/CONTEXT.md. Uses: Secondary Separator, Always-hidden zone, Toggle Icon, Show Always Hidden Icons / Hide Always Hidden Icons, Default layout, ⌘-drag arrange.

## Decisions
- The Toggle Icon is excluded from always-hiding by identity (it is PeekBar's toggle), not by position, so any ⌘-drag arrangement is safe and never hides the app's own control.
- The Secondary Separator is styled semi-translucent and dashed to distinguish the permanently-hidden boundary from the solid Primary Separator's normal-collapse boundary (see 0001). Both separators are required, inflatable status items — a single-item design is not achievable (see docs/adr/0002-two-status-items-minimum.md).
