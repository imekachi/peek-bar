# First-launch Onboarding
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
PeekBar's hiding only works after the user ⌘-drags their menu-bar icons around the separators — a non-obvious macOS gesture. New users who don't know this will think the app is broken. A one-time onboarding explains the setup.

## Goals
- Teach new users how to arrange icons so hiding works.
- Surface this the first time, without nagging afterward.

## Non-goals (out of scope)
- A multi-step interactive tutorial or animations (plain instructions suffice).
- The Preferences window mechanics themselves (see 0002); this spec defines the onboarding content shown within it.

## Behavior / Requirements
- Onboarding content lives inside the Preferences window (see 0002).
- It explains, at minimum: that the Toggle Icon `›`/`‹` hides/reveals the items to its left; and that the user must ⌘-drag menu-bar icons to position them to the left of the Toggle Icon (and, when the always-hidden feature is enabled, to the left of the Secondary Separator for the Always-hidden zone).
- On first launch, the Preferences window opens automatically (see 0002) so the onboarding content is seen.
- The onboarding is informational, remains available in Preferences afterward, and does not block use of the app.

## Domain terms
See docs/specs/CONTEXT.md. Uses: Toggle Icon, Secondary Separator, Normal-collapse zone, Always-hidden zone, ⌘-drag arrange.

## Decisions
- Onboarding is embedded in Preferences (not a separate modal) and reused as always-available help, avoiding a throwaway first-run-only screen.
