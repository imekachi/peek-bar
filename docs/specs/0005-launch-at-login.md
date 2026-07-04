# Launch at Login
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
A menu-bar utility is only useful while it is running. Users expect PeekBar to start automatically when they log in so the bar stays tidy without manual launching.

## Goals
- Start PeekBar automatically when the user logs in.
- Let users turn this behavior on/off.
- Default to on so the utility works without extra setup.

## Non-goals (out of scope)
- Managing login items for any app other than PeekBar.

## Behavior / Requirements
- Preferences exposes a "Launch at login" toggle (see 0002).
- Default: on.
- When on, PeekBar launches automatically at user login.
- When off, PeekBar does not launch at login.
- The setting persists and reflects the actual system login-item state; if the user changes it in macOS System Settings, the toggle reflects that reality.

## Domain terms
See docs/specs/CONTEXT.md. Uses: PeekBar.

## Decisions
- Default on: the utility is only useful while running, so auto-start is the expected baseline.
- Relies on the current macOS login-item mechanism (macOS 26 Tahoe+ per 0001), with no legacy fallback.
