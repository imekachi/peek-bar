---
name: peekbar-ui-testing
description: UI-test and verify the PeekBar macOS menu-bar app end-to-end from a fresh agent session. Use when asked to test, verify, QA, exercise, or reproduce PeekBar's menu-bar behavior — clicking the toggle icon to collapse/expand icons, opening the right-click/Ctrl-click context menu, opening and asserting the Preferences window (title, Version 0.1.0, section labels), or ⌘-dragging status items to reposition/reorder them. Drives real mouse/keyboard events and AX reads through the `macos_automator` MCP (execute_script) plus the bundled JXA driver script.
---

# PeekBar UI Testing

Drive and assert PeekBar's menu-bar UI from any agent session using the `macos_automator` MCP and the bundled JXA driver (`scripts/peekbar-driver.js`). All interaction — AX state reads, real mouse/keyboard events, the Preferences window dump, and screenshots — goes through the single `macos_automator` server; no other MCP is required.

## When to use

- Verify the toggle icon collapses/expands the hidden icons.
- Open the context menu (Settings / About / Quit) and open the Settings window.
- Assert Settings window contents (title, `Version`, `0.1.0 (1)`, section labels) without a screenshot.
- ⌘-drag status items to reorder them and confirm the new order.
- Capture a screenshot of the menu-bar region.

## App facts (hardcoded, PeekBar-specific)

- SwiftUI/AppKit menu-bar utility, `NSApp.setActivationPolicy(.accessory)` (no Dock icon). Bundle id `com.imekachi.PeekBar`.
- Two `NSStatusItem`s: the **toggle** (AX description `"Collapse menu bar icons"` when expanded, `"Expand menu bar icons"` when collapsed) and the **separator** (AX description `"status menu"`, a thin vertical line).
- Left-click the toggle → collapse/expand. Ctrl+left-click the toggle → context menu (shown via `NSMenu.popUp`, NOT attached as `statusItem.menu`).
- Context menu, enabled order: **Settings** (⌘,), **About**, **Quit** (`"Check for updates…"` sits between Settings and About but is disabled, so keyboard nav skips it).
- Settings is a normal titled `NSWindow` (title `"Settings"`), with rows including `Version` / `0.1.0 (1)` and section labels `General`, `Menu Bar`, `Updates`. The driver's `prefsWindow()` matches `/preferences/i` but falls back to the first window, so it still resolves after the rename.

## Prerequisites

1. **`macos_automator` MCP enabled** (the only MCP this skill needs). It exposes `execute_script`, which runs AppleScript or JXA.
2. **Permissions granted to the host running the MCP (Cursor):** Accessibility (for AX reads + synthetic events) and Screen Recording (for `screencapture`).
3. **PeekBar built and running.**

Build (Debug, signing off):

```bash
cd /Users/imekachi/Projects/tools/hidden-bar && xcodebuild -project PeekBar.xcodeproj -scheme PeekBar -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build
```

Launch and discover the pid (the pid changes every launch — always rediscover):

```bash
open /Users/imekachi/Projects/tools/hidden-bar/build/Build/Products/Debug/PeekBar.app
pgrep -f "PeekBar.app/Contents/MacOS/PeekBar"
```

## Calling the driver

Invoke `macos_automator`'s `execute_script` with the driver's absolute path, `language: "javascript"`, and `arguments` (an array passed to JXA `run(argv)`). Paths below are **user/machine-specific** — derive them from your repo root on other machines.

```json
{
  "language": "javascript",
  "script_path": "/Users/imekachi/Projects/tools/hidden-bar/.cursor/skills/peekbar-ui-testing/scripts/peekbar-driver.js",
  "arguments": ["state"],
  "timeout_seconds": 15
}
```

`state` / `items` are instant; use `timeout_seconds: 45` for menu/drag/prefs commands (they include deliberate sleeps).

### Commands

| `arguments` | What it does | Example output |
|---|---|---|
| `["state"]` / `["items"]` | Read AX state: `collapsed`, `toggleLabel`, and each item's position/size/center (`items` is an alias — same JSON). | `{"collapsed":false,"toggleLabel":"Collapse menu bar icons","items":[...]}` |
| `["toggle"]` | One left-click on the toggle, then re-read state. | state with `collapsed` flipped |
| `["collapse"]` / `["expand"]` | Idempotently reach the desired state. | state with `collapsed` true/false |
| `["menu-select","1"]` | **Reliable** one-shot: open the context menu and activate the Nth enabled item via keyboard (1=Preferences, 2=About, 3=Quit), then dump the resulting window. | Preferences window dump (see below) |
| `["open-prefs"]` | Convenience for `menu-select 1`; opens Preferences and returns its dump. | `{"window":"Preferences","texts":["Version","0.1.0 (1)","Menu Bar","Updates","Preferences"]}` |
| `["open-prefs-coord"]` | Coordinate **fallback**: open the menu, then click the Preferences row by offset from the toggle center. Prefer keyboard (`open-prefs`); use this only if keyboard nav misbehaves. | same Preferences dump |
| `["window"]` | Count PeekBar windows + first title. | `{"windows":1,"title":"Preferences"}` |
| `["window-dump"]` | Dump the Preferences window's static-text values as JSON (for assertions). | `{"window":"Preferences","texts":["Version","0.1.0 (1)","Menu Bar","Updates","Preferences"]}` |
| `["close-window"]` | Click the first window's close button. | `{"closed":true}` or `close-window: no window to close` |
| `["drag","0","-50"]` | ⌘-drag item at index `0` by `dx` px along the bar (y derived from item geometry, clamped inside the bar). Returns before/after item order. Re-dragging index `0` restores order because `menuBarItems()` order is stable by item identity. | `{"before":[...],"after":[...]}` |
| `["screenshot","/tmp/peekbar.png"]` | Capture a tight region around the items (excludes the inflated separator) via `screencapture`. | `{"path":"/tmp/peekbar.png","region":"-R...,0,...,28"}` |
| `["menu-open"]` | **Primitive:** open the context menu only and leave it open. AX is then blocked (see gotcha 4). | status message |
| `["menu-key","1"]` | **Advanced primitive:** send `Down×n` + `Return` to an already-open menu. Timing-sensitive across separate MCP calls — prefer `menu-select`. | status message |

### Asserting the Preferences window (through `macos_automator` only)

`window-dump` reads the window's AX tree via System Events AppleScript-equivalent JXA and returns every `AXStaticText` value. Assert against it directly — no screenshot, no second MCP:

```json
{
  "language": "javascript",
  "script_path": "/Users/imekachi/Projects/tools/hidden-bar/.cursor/skills/peekbar-ui-testing/scripts/peekbar-driver.js",
  "arguments": ["window-dump"],
  "timeout_seconds": 30
}
```

Expected: `texts` contains `"Version"` and `"0.1.0 (1)"` (version assertion) plus section labels `"Menu Bar"` and `"Updates"`. If you need a raw AppleScript equivalent, the same idea is:

```applescript
tell application "System Events" to tell application process "PeekBar"
  set winTitle to title of window "Preferences"
  set vals to value of every static text of window "Preferences" -- (recurse groups as needed)
end tell
```

## Critical gotchas (do not rediscover these)

1. **`AXPress` does not work on the toggle.** PeekBar inspects `NSApp.currentEvent` and only reacts to *real* mouse events. The driver synthesizes CGEvent mouse events posted to the session event tap (`kCGSessionEventTap = 1`). A plain left-click at the toggle center collapses/expands.
2. **Synthetic right-click does not open the context menu.** `rightMouseDown/Up` won't trigger it. **Ctrl+left-click does** (same code path). So "right-click" in tests = a left-click carrying `kCGEventFlagMaskControl` (`0x40000 = 262144`). The driver's menu commands already do this.
3. **⌘-drag reposition:** `leftMouseDown → several leftMouseDragged → leftMouseUp`, all carrying `kCGEventFlagMaskCommand` (`0x100000 = 1048576`), keeping **y inside the item's menu-bar band** (driver: `mi.y + min(12, h/2)`, clamped). Dragging **below** the bar removes the item — don't.
4. **While the context menu is open, PeekBar's main thread is in a modal tracking loop, so any AX query to PeekBar BLOCKS/hangs.** Read AX state *before* opening the menu; while it's open, use only CGEvent keyboard/mouse. This is why menu navigation must happen inside a single script run.
5. **Open Preferences via keyboard, in one script run.** `menu-select`/`open-prefs` do Ctrl+left-click → `Down` → `Return` in one `execute_script` call, which keeps the timing tight and is reliable. Splitting `menu-open` + `menu-key` across two MCP calls is racy (the first `Down` is inconsistently consumed) — avoid it. Coordinate clicking the row (`open-prefs-coord`) is the fallback.
6. **AppleScript coercion gotcha:** `item 1 of (position of mi)` can error intermittently. Assign first (`set p to position of mi` then `item 1 of p`). The JXA driver already reads `position()`/`size()` into locals.
7. **Screenshots need Screen Recording** (grant it to Cursor). `screencapture -x -R<x>,<y>,<w>,<h> <path>` works with **negative** x on a left-of-primary display.
8. **Always read coordinates fresh every run.** The pid, the item positions, and even the sign of x change between runs (a two-display setup puts the bar left of primary → negative x; AX `position` and CGEvent global coordinates share that space). Collapsing also inflates the separator's width to thousands of px. The driver recomputes `position + size/2` on every call — never hardcode coordinates.

## End-to-end example recipe

Run each as a separate `execute_script` call with the `script_path` above:

1. `["state"]` → assert `collapsed: false` (expanded).
2. `["toggle"]` → assert `collapsed: true` and `toggleLabel: "Expand menu bar icons"` (the separator width balloons — that's expected).
3. `["expand"]` → back to `collapsed: false`.
4. `["open-prefs"]` → assert returned `texts` include `"Version"` and `"0.1.0 (1)"` (right-click menu → Preferences → version assertion, all in one).
5. `["close-window"]` then `["window"]` → assert `{"windows":0}`.
6. `["drag","0","-50"]` → assert `before` had the separator (`"status menu"`) left of the toggle and `after` swapped them.
7. `["drag","0","50"]` → assert the original order is restored (separator left of toggle).
8. Optional: `["screenshot","/tmp/peekbar.png"]` → read the PNG to eyeball the bar.

## Cleanup

Leave PeekBar **expanded** and in its **original order** (separator to the left of the toggle), with no Preferences window open:

- `["expand"]`, close any window with `["close-window"]`, and restore order with a compensating `["drag", ...]` if you swapped items.
- To quit PeekBar entirely: `pkill -f "PeekBar.app/Contents/MacOS/PeekBar"`.

Do not modify PeekBar app source (`PeekBar/**`); this skill only reads and drives the running app.
