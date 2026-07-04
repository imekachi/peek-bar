# Auto-collapse Timer
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
After a user expands to peek at hidden icons, they usually want the bar to tidy itself again without a manual click. Auto-collapse re-hides the revealed items after a chosen interval.

## Goals
- Automatically collapse the Normal-collapse zone a chosen interval after it was expanded.
- Let users pick the interval or turn the feature off.

## Non-goals (out of scope)
- Auto-hiding the Always-hidden zone (see 0003; that is manual reveal/hide only).
- Scheduled or activity-based hiding beyond the single post-expand timer.

## Behavior / Requirements
- Auto-collapse is configured in Settings (see 0002) with choices: Off, 10s, 15s, 30s, 60s.
- Default is Off.
- When set to an interval and the user expands (Toggle Icon → `›`), a countdown of that interval starts.
- When the countdown elapses, PeekBar collapses the Normal-collapse zone automatically (Toggle Icon → `‹`), identical in effect to a manual collapse.
- Manually collapsing before the countdown elapses cancels the pending auto-collapse.
- Changing the interval takes effect on the next expand; selecting Off disables auto-collapse entirely.
- The selected interval persists across relaunch.

## Domain terms
See docs/specs/CONTEXT.md. Uses: Normal-collapse zone, Collapse / Expand, Toggle Icon.

## Decisions
- The timer is anchored to the expand action (it starts when the zone is expanded), not to broader user activity, to keep the behavior predictable.
