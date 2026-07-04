# Product

## Register

product

## Users

macOS users with crowded menu bars — people who run many status-bar apps and want a calmer, tidier bar. Their context: PeekBar lives in the menu bar and is used almost entirely from there (one click to collapse/expand, a right-click menu for the rest). The job to be done is "hide the clutter, reveal it on demand, and keep rarely-used icons permanently out of sight."

The Settings window is an occasional destination, not a hub: opened once on first launch to learn the one non-obvious setup step (⌘-drag arranging icons around the separators), and rarely thereafter to flip a setting. It must therefore be instantly legible and require near-zero learning.

## Product Purpose

PeekBar is a lightweight macOS menu-bar utility that declutters the system menu bar. A single Toggle Icon collapses/expands the normal items, and an optional Always-hidden zone keeps chosen icons permanently hidden. It runs as a background accessory app — no Dock icon, no main application window.

Success looks like: the menu bar feels calmer; the toggle is instant and reliable; the current state (expanded `›` / collapsed `‹`) is always unambiguous; and new users understand the single hard setup step without frustration. The app should feel like a native, built-in part of macOS rather than a third-party add-on.

## Brand Personality

Calm, precise, unobtrusive. PeekBar behaves like a good system utility: it does its job, stays out of the way, and never demands attention. Its voice in copy is plain and instructional — direct, concise, and helpful, the way Apple's own System Settings reads. The emotional goal is quiet confidence and relief (a tidier bar), never excitement or persuasion.

## Anti-references

- **Non-native / Electron-style UIs** that fight macOS conventions: custom window chrome, non-standard controls, wrong fonts, off spacing, invented affordances for standard tasks.
- **Over-branded, gamified, gradient-heavy SaaS aesthetics**: hero-metric templates, marketing flourishes, decorative color, or personality bolted onto a settings surface.
- **Naggy patterns**: upsell popups, attention-grabbing badges, modal interruptions, "rate us" prompts, update nagging.
- **A settings surface that is itself cluttered** — an app about reducing clutter must not add its own.

## Design Principles

- **Native by default.** Match macOS System Settings conventions (SwiftUI `Settings`/`Form`, standard controls, system typography and spacing). When in doubt, do exactly what Apple does — earned familiarity beats novelty.
- **Invisible until needed.** The product's real surface is the menu bar; Settings is a quiet, occasional destination, not a dashboard. Don't grow it into a hub.
- **Teach the one hard thing well.** The ⌘-drag setup is the only non-obvious step. Onboarding must make it obvious once, remain available as help afterward, and otherwise get out of the way.
- **Instant and reliable.** The toggle and every setting take effect immediately — no restart, no ambiguity about the current state.
- **Respect the user's attention.** No nagging, no upsells, no motion for motion's sake; state-conveying feedback only.

## Accessibility & Inclusion

Lean on the native macOS accessibility that standard SwiftUI/AppKit controls provide for free — VoiceOver labels, full keyboard navigation, Dynamic Type, Increase Contrast, and Reduce Motion. The directive is "don't over-engineer beyond platform defaults," but equally "don't defeat them": use standard controls and system colors so the OS's own accessibility settings just work. Menu-bar glyphs (`›` `‹` `ǀ`) and the app icon must stay legible in both light and dark menu bars.
