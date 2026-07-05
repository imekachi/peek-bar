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
- The app icon features a `›` symbol as its central motif, with room for visual refinement as long as it stays recognizably tied to PeekBar's Toggle Icon.
- The background is a darker, macOS-style app-icon surface with a subtle gradient/depth treatment. It should feel native and polished, not flat marketing artwork.
- The icon no longer uses the earlier two-tone diagonal split; the background should read as one coherent dark surface.
- The `›` motif remains clearly legible at all required macOS app-icon sizes, including small Finder/About sizes.
- The icon follows macOS application-icon conventions: rounded app-icon field, balanced optical padding, restrained depth, and no text/badges.
- The icon is delivered at all macOS application-icon sizes/resolutions required by the system.

## Domain terms
See docs/specs/CONTEXT.md. Uses: PeekBar, Toggle Icon.

## Decisions
- The icon reuses the `›` toggle glyph as its motif so the application icon and the menu-bar identity stay visually consistent.
- The earlier two-tone diagonal concept was removed in favor of a darker native gradient background and a more polished, creative `›` mark.
