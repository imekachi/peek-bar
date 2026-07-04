# App Icon Design
> Ticket: NO_TICKET  ·  Status: active

## Problem / Why
PeekBar is a new app and needs its own distinct application icon (for Finder, the About panel, installers, and general branding). The icon should echo the core `›` toggle concept so the app's identity is consistent.

## Goals
- Define a distinctive application icon for PeekBar centered on the `›` symbol.
- Ensure it reads clearly at macOS icon sizes.

## Non-goals (out of scope)
- The menu-bar glyphs (`›` `‹` `ǀ`) themselves — those are reused from the reference project's assets (see 0001); this spec covers only the application icon.
- Marketing artwork beyond the app icon.

## Behavior / Requirements
- The app icon features a `›` symbol over a background split diagonally from the top-left corner to the bottom-right corner into two triangular halves.
- Bottom-left half: dark background; the portion of the `›` line over it is light.
- Top-right half: light background; the portion of the `›` line over it is dark (the reverse of the other half).
- The `›` line therefore switches from light to dark across the diagonal split, remaining legible on both halves.
- The icon is delivered at all macOS application-icon sizes/resolutions required by the system, following macOS icon conventions.

## Domain terms
See docs/specs/CONTEXT.md. Uses: PeekBar, Toggle Icon.

## Decisions
- The icon reuses the `›` toggle glyph as its motif so the application icon and the menu-bar identity stay visually consistent.
