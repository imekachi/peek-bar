# Preferences Window
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
Several PeekBar features are configurable and must share a single, discoverable settings surface. Because other features read their settings from here, Preferences is foundational. It is also the first thing a new user sees, so it doubles as the host for onboarding.

## Goals
- Provide one Preferences window exposing all user-configurable settings.
- Persist all settings across launches.
- Open automatically on first launch so new users find setup and instructions.

## Non-goals (out of scope)
- The onboarding instructional content itself (see 0006) — Preferences hosts it, but 0006 defines it.
- The behavior/semantics of each feature (defined in its own spec); this spec covers only their presence and surfacing as settings.
- A separate settings window for any individual feature.

## Behavior / Requirements
- A Preferences window is reachable from the right-click menu's "Preferences" item (see 0001).
- Preferences exposes exactly these settings:
  1. Launch at login — on/off toggle (see 0005).
  2. Auto-collapse interval — selectable: Off / 10s / 15s / 30s / 60s (see 0004).
  3. Enable always-hidden section — on/off toggle (see 0003).
  4. Automatically check for updates — on/off toggle (see 0007).
  5. Current version display plus a "Check for Updates" action (see 0007).
- Preferences also hosts the first-launch onboarding content (see 0006).
- All settings persist across relaunch and reboot; changing a setting takes effect without an app restart.
- On first launch (no saved settings yet), the Preferences window opens automatically. On subsequent launches it does not auto-open.

## Domain terms
See docs/specs/CONTEXT.md. Uses: PeekBar.

## Decisions
- Preferences is the single settings host for all features; individual features do not define separate settings windows.
