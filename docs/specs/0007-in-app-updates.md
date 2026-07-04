# In-app Updates
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
PeekBar is distributed outside the App Store (direct download), so it needs its own way to keep users on the latest version. Update artifacts are published on the project's GitHub Releases.

## Goals
- Notify users when a newer version is available and let them update in one click.
- Let users check for updates manually.
- Show the current version to the user.
- Use GitHub Releases as the update source.

## Non-goals (out of scope)
- App Store auto-updates (PeekBar is not distributed there).
- Silent or forced background updates without user consent.
- Delta/differential updates (updating with the full released artifact is acceptable).

## Behavior / Requirements
- PeekBar checks for updates automatically: on launch and periodically thereafter.
- Automatic checking is governed by the "Automatically check for updates" toggle in Preferences (see 0002); default on.
- When a newer version is found, PeekBar notifies the user and offers a one-click action to download, install, and relaunch into the new version.
- The right-click menu includes "Check for updates…" and Preferences includes a "Check for Updates" action; both trigger an immediate check. If no newer version exists, the user is told they are up to date.
- Preferences displays the current app version.
- The update source is the project's GitHub Releases; the update payload is the released app artifact.
- Downloaded update artifacts are verified as authentic before installation; tampered or unverified downloads are rejected and not installed.

## Domain terms
See docs/specs/CONTEXT.md. Uses: PeekBar.

## Decisions
- Update feed = GitHub Releases. Rationale: releases are already published there; this avoids running separate update infrastructure.
- Updates are user-consented (notify + one-click), not silent, to respect user control.
- Downloaded updates must pass authenticity verification before install — a security requirement for out-of-store distribution.
