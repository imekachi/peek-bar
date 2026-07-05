'use strict';

// PeekBar UI-test driver (JXA). Runs via the `macos_automator` MCP:
//   execute_script { language:"javascript", script_path:"<abs path to this file>", arguments:[cmd, ...] }
//
// AX reads use System Events. Real mouse/keyboard use CGEvent posted to the
// session event tap, because PeekBar inspects NSApp.currentEvent and ignores
// synthetic AXPress. See SKILL.md for the full rationale and gotchas.

ObjC.import('CoreGraphics');
ObjC.import('Foundation');

var APP = 'PeekBar';
var TAP = 1; // kCGSessionEventTap
var CMD = 1048576; // kCGEventFlagMaskCommand
var CTRL = 262144; // kCGEventFlagMaskControl
var MENU_ITEMS_MAX = 4; // enabled: Settings, Check for updates, About, Quit
var DRAG_DX_MAX = 400;

// CGEventType numeric constants
var MOUSE_MOVED = 5;
var LEFT_DOWN = 1;
var LEFT_UP = 2;
var RIGHT_DOWN = 3;
var RIGHT_UP = 4;
var LEFT_DRAG = 6;

function sleep(s) {
  $.NSThread.sleepForTimeInterval(s);
}

function se() {
  return Application('System Events');
}

function peekBarRunning() {
  try {
    return se().applicationProcesses.byName(APP).exists();
  } catch (e) {
    return false;
  }
}

function proc() {
  return se().applicationProcesses.byName(APP);
}

function menuItemsRaw() {
  if (!peekBarRunning()) return null;
  try {
    var arr = proc().menuBars[0].menuBarItems();
    return arr && arr.length ? arr : null;
  } catch (e) {
    return null;
  }
}

function items() {
  var arr = menuItemsRaw();
  if (!arr) return null;
  var out = [];
  for (var i = 0; i < arr.length; i++) {
    var mi = arr[i];
    var p = mi.position();
    var s = mi.size();
    out.push({
      index: i,
      desc: mi.description(),
      x: p[0], y: p[1], w: s[0], h: s[1],
      cx: Math.round(p[0] + s[0] / 2),
      cy: Math.round(p[1] + s[1] / 2)
    });
  }
  return out;
}

function requireItems() {
  if (!peekBarRunning()) return 'PeekBar process not running';
  var it = items();
  if (!it || !it.length) return 'no menu bar items found';
  return it;
}

function toggle() {
  var it = requireItems();
  if (typeof it === 'string') return it;
  for (var i = 0; i < it.length; i++) {
    if (/menu bar icons/i.test(it[i].desc)) return it[i];
  }
  return it[0];
}

function separator() {
  var it = requireItems();
  if (typeof it === 'string') return it;
  for (var i = 0; i < it.length; i++) {
    if (/status menu|separator/i.test(it[i].desc)) return it[i];
  }
  return it[it.length - 1];
}

function state() {
  var t = toggle();
  if (typeof t === 'string') return t;
  return {
    collapsed: /expand/i.test(t.desc),
    toggleLabel: t.desc,
    items: items()
  };
}

function postMouse(type, x, y, btn, flags) {
  var src = $.CGEventSourceCreate(TAP);
  var e = $.CGEventCreateMouseEvent(src, type, $.CGPointMake(x, y), btn);
  if (flags) $.CGEventSetFlags(e, flags);
  $.CGEventPost(TAP, e);
}

function click(x, y, opts) {
  opts = opts || {};
  var flags = opts.flags || 0;
  var right = !!opts.right;
  var btn = right ? 1 : 0;
  var down = right ? RIGHT_DOWN : LEFT_DOWN;
  var up = right ? RIGHT_UP : LEFT_UP;
  postMouse(MOUSE_MOVED, x, y, 0, flags);
  sleep(0.12);
  postMouse(down, x, y, btn, flags);
  sleep(0.09);
  postMouse(up, x, y, btn, flags);
  sleep(0.15);
}

function cmdDrag(x0, y0, x1, y1) {
  postMouse(MOUSE_MOVED, x0, y0, 0, CMD);
  sleep(0.12);
  postMouse(LEFT_DOWN, x0, y0, 0, CMD);
  sleep(0.18);
  var steps = 14;
  for (var i = 1; i <= steps; i++) {
    var x = x0 + (x1 - x0) * i / steps;
    var y = y0 + (y1 - y0) * i / steps;
    postMouse(LEFT_DRAG, x, y, 0, CMD);
    sleep(0.035);
  }
  sleep(0.1);
  postMouse(LEFT_UP, x1, y1, 0, CMD);
  sleep(0.3);
}

function key(code, flags) {
  var src = $.CGEventSourceCreate(TAP);
  var d = $.CGEventCreateKeyboardEvent(src, code, true);
  var u = $.CGEventCreateKeyboardEvent(src, code, false);
  if (flags) {
    $.CGEventSetFlags(d, flags);
    $.CGEventSetFlags(u, flags);
  }
  $.CGEventPost(TAP, d);
  sleep(0.05);
  $.CGEventPost(TAP, u);
  sleep(0.08);
}

function shellQuote(s) {
  return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function doShell(cmd) {
  var app = Application.currentApplication();
  app.includeStandardAdditions = true;
  return app.doShellScript(cmd);
}

function windowCount() {
  if (!peekBarRunning()) return 0;
  try {
    return proc().windows().length;
  } catch (e) {
    return 0;
  }
}

// Find the Settings NSWindow (falls back to first window).
function settingsWindow() {
  var pr = proc();
  var wins = pr.windows();
  for (var i = 0; i < wins.length; i++) {
    var t = '';
    try { t = wins[i].title(); } catch (e) {}
    if (/settings/i.test(t)) return wins[i];
  }
  return wins.length ? wins[0] : null;
}

// Recursively collect AXStaticText values/titles under an element.
function collectStatic(el, out, depth) {
  if (depth > 10) return;
  var kids;
  try { kids = el.uiElements(); } catch (e) { return; }
  for (var i = 0; i < kids.length; i++) {
    var k = kids[i];
    var role = '';
    try { role = k.role(); } catch (e) {}
    if (role === 'AXStaticText') {
      var v = '';
      try { v = k.value(); } catch (e) {}
      if (!v || typeof v !== 'string') {
        try { v = k.title(); } catch (e) {}
      }
      if (v && typeof v === 'string' && v.length) out.push(v);
    }
    collectStatic(k, out, depth + 1);
  }
}

function collectButtons(el, out, depth) {
  if (depth > 10) return;
  var kids;
  try { kids = el.uiElements(); } catch (e) { return; }
  for (var i = 0; i < kids.length; i++) {
    var k = kids[i];
    var role = '';
    var desc = '';
    try { role = k.role(); } catch (e) {}
    try { desc = k.description(); } catch (e) {}
    if (role === 'AXButton' && desc === 'button') {
      var title = '';
      var enabled = null;
      try { title = k.title(); } catch (e) {}
      if (!title || typeof title !== 'string') {
        try { title = k.value(); } catch (e) {}
      }
      try { enabled = k.enabled(); } catch (e) {}
      out.push({
        title: title && typeof title === 'string' ? title : null,
        enabled: enabled
      });
    }
    collectButtons(k, out, depth + 1);
  }
}

function windowDump() {
  var win = settingsWindow();
  if (!win) return { window: null, texts: [], buttons: [] };
  var out = [];
  var buttons = [];
  collectStatic(win, out, 0);
  collectButtons(win, buttons, 0);
  var title = '';
  try { title = win.title(); } catch (e) {}
  return { window: title, texts: out, buttons: buttons };
}

function menuDump() {
  var to = toggle();
  if (typeof to === 'string') return to;
  click(to.cx, to.cy, { flags: CTRL });
  sleep(0.4);
  var items = [];
  try {
    var mbs = proc().menuBars[0].menuBarItems;
    for (var i = 0; i < mbs.length; i++) {
      var d = '';
      try { d = mbs[i].description(); } catch (e) {}
      if (!/collapse|expand/i.test(d)) continue;
      var menu = mbs[i].menus[0];
      var menuItems = menu.menuItems();
      for (var j = 0; j < menuItems.length; j++) {
        var name = '';
        var enabled = null;
        try { name = menuItems[j].name(); } catch (e) {}
        try { enabled = menuItems[j].enabled(); } catch (e) {}
        if (!name) continue;
        items.push({ index: items.length + 1, name: name, enabled: enabled });
      }
    }
  } catch (e) {
    key(53);
    sleep(0.2);
    return 'menu-dump: failed to read menu items — ' + e;
  }
  key(53);
  sleep(0.2);
  return { menuItems: items };
}

function validateMenuN(argv, label) {
  var raw = argv[1];
  if (raw === undefined || raw === '') {
    return label + ': selection index required (1-' + MENU_ITEMS_MAX + ')';
  }
  var n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > MENU_ITEMS_MAX) {
    return label + ': selection index must be integer 1-' + MENU_ITEMS_MAX;
  }
  return n;
}

function menuInteractionResult(failureMsg) {
  if (windowCount() > 0) {
    return JSON.stringify(windowDump(), null, 2);
  }
  key(53); // Escape — dismiss menu if still open
  sleep(0.2);
  if (windowCount() > 0) {
    return JSON.stringify(windowDump(), null, 2);
  }
  return failureMsg;
}

// Open the context menu and activate the Nth enabled item via keyboard, all in
// ONE script run. Enabled order: 1=Settings, 2=Check for updates…, 3=About,
// 4=Quit. Doing this in a single run keeps the click->Down->Return timing
// tight; splitting menu-open and menu-key across separate MCP calls is racy.
function menuSelect(n) {
  var to = toggle();
  if (typeof to === 'string') return to;
  click(to.cx, to.cy, { flags: CTRL });
  sleep(0.35);
  for (var i = 0; i < n; i++) {
    key(125); // Down
    sleep(0.05);
  }
  sleep(0.1);
  key(36); // Return
  sleep(0.5);
}

// Coordinate fallback: open the menu, then left-click the Settings row by
// offset from the toggle center (menu drops below-right of the status item).
// Keyboard (menuSelect) is recommended; this exists as a documented fallback.
function openSettingsByCoordinate() {
  var to = toggle();
  if (typeof to === 'string') return to;
  click(to.cx, to.cy, { flags: CTRL });
  sleep(0.35);
  click(to.cx + 20, to.cy + 36); // Settings is the first row under the toggle
  sleep(0.5);
}

function safeDragY(mi) {
  var raw = mi.y + Math.min(12, mi.h / 2);
  var minY = mi.y + 2;
  var maxY = mi.y + mi.h - 2;
  return Math.max(minY, Math.min(maxY, raw));
}

// Screenshot a region around the current menu-bar items. Excludes the
// collapsed separator (its width balloons to thousands of px) so the region
// stays tight. Requires Screen Recording permission for the host (Cursor).
function screenshot(path) {
  path = path || '/tmp/peekbar.png';
  var it = requireItems();
  if (typeof it === 'string') return it;
  var starts = [];
  var ends = [];
  for (var i = 0; i < it.length; i++) {
    if (it[i].w < 200) {
      starts.push(it[i].x);
      ends.push(it[i].x + it[i].w);
    }
  }
  if (!starts.length) {
    // Fallback: center on the toggle if everything is inflated.
    var t = toggle();
    if (typeof t === 'string') return t;
    starts.push(t.cx - 30);
    ends.push(t.cx + 30);
  }
  var minX = Math.round(Math.min.apply(null, starts) - 30);
  var maxX = Math.round(Math.max.apply(null, ends) + 30);
  var w = maxX - minX;
  var region = '-R' + minX + ',0,' + w + ',28';
  doShell('screencapture -x ' + region + ' ' + shellQuote(path));
  return { path: path, region: region };
}

function run(argv) {
  var cmd = argv[0];

  if (cmd === 'state' || cmd === 'items') {
    var st = state();
    if (typeof st === 'string') return st;
    return JSON.stringify(st, null, 2);
  }

  if (cmd === 'toggle') {
    var t0 = toggle();
    if (typeof t0 === 'string') return t0;
    click(t0.cx, t0.cy);
    sleep(0.3);
    return JSON.stringify(state(), null, 2);
  }

  if (cmd === 'collapse' || cmd === 'expand') {
    var st1 = state();
    if (typeof st1 === 'string') return st1;
    var want = (cmd === 'collapse');
    if (st1.collapsed !== want) {
      var tg = toggle();
      if (typeof tg === 'string') return tg;
      click(tg.cx, tg.cy);
      sleep(0.3);
    }
    return JSON.stringify(state(), null, 2);
  }

  if (cmd === 'menu-open') {
    var to = toggle();
    if (typeof to === 'string') return to;
    click(to.cx, to.cy, { flags: CTRL });
    return 'menu-open: context menu shown via Ctrl+left-click. PeekBar AX is now BLOCKED (modal tracking) until the menu closes; use keyboard/mouse only (no AX reads).';
  }

  if (cmd === 'menu-key') {
    // Advanced primitive: send Down x n + Return to an ALREADY-open menu.
    // Timing-sensitive across separate MCP calls; use `menu-select`.
    var nk = validateMenuN(argv, 'menu-key');
    if (typeof nk === 'string') return nk;
    for (var i = 0; i < nk; i++) key(125); // 125 = Down arrow
    key(36); // 36 = Return
    return 'menu-key: Down x' + nk + ' + Return';
  }

  if (cmd === 'menu-dump') {
    if (!peekBarRunning()) return 'PeekBar process not running';
    var dump = menuDump();
    if (typeof dump === 'string') return dump;
    return JSON.stringify(dump, null, 2);
  }

  if (cmd === 'menu-select') {
    // One-shot reliable menu activation. n: 1=Settings, 2=Check for updates…, 3=About, 4=Quit.
    var sel = validateMenuN(argv, 'menu-select');
    if (typeof sel === 'string') return sel;
    var selErr = menuSelect(sel);
    if (typeof selErr === 'string') return selErr;
    return menuInteractionResult(
      'menu-select: no window opened (selection ' + sel + ' may have failed)'
    );
  }

  if (cmd === 'open-settings') {
    var selErr2 = menuSelect(1);
    if (typeof selErr2 === 'string') return selErr2;
    return menuInteractionResult('open-settings: Settings window did not open');
  }

  if (cmd === 'open-settings-coord') {
    var coordErr = openSettingsByCoordinate();
    if (typeof coordErr === 'string') return coordErr;
    return menuInteractionResult('open-settings-coord: Settings window did not open');
  }

  if (cmd === 'window') {
    if (!peekBarRunning()) return 'PeekBar process not running';
    var wins = proc().windows();
    if (!wins.length) return JSON.stringify({ windows: 0 });
    return JSON.stringify({ windows: wins.length, title: wins[0].title() });
  }

  if (cmd === 'window-dump') {
    if (!peekBarRunning()) return 'PeekBar process not running';
    if (!windowCount()) return JSON.stringify({ window: null, texts: [] });
    return JSON.stringify(windowDump(), null, 2);
  }

  if (cmd === 'close-window') {
    if (!peekBarRunning()) return 'PeekBar process not running';
    try {
      var cw = proc().windows();
      if (!cw.length) return 'close-window: no window to close';
      cw[0].buttons[0].click();
      sleep(0.2);
      return JSON.stringify({ closed: true });
    } catch (e) {
      return 'close-window: failed to close window';
    }
  }

  if (cmd === 'drag') {
    var before = requireItems();
    if (typeof before === 'string') return before;

    if (argv[1] === undefined || argv[1] === '') {
      return 'drag: index required';
    }
    var idx = Number(argv[1]);
    if (!Number.isInteger(idx)) {
      return 'drag: index must be an integer';
    }
    if (idx < 0 || idx >= before.length) {
      return 'drag: index ' + idx + ' out of range (0-' + (before.length - 1) + ')';
    }

    if (argv[2] === undefined || argv[2] === '') {
      return 'drag: delta required';
    }
    var dx = Number(argv[2]);
    if (!Number.isFinite(dx)) {
      return 'drag: delta must be a number';
    }
    dx = Math.max(-DRAG_DX_MAX, Math.min(DRAG_DX_MAX, dx));

    var mi = before[idx];
    var safeY = safeDragY(mi);
    cmdDrag(mi.cx, safeY, mi.cx + dx, safeY);
    return JSON.stringify({
      before: before.map(function (o) { return { desc: o.desc, x: o.x }; }),
      after: items().map(function (o) { return { desc: o.desc, x: o.x }; })
    }, null, 2);
  }

  if (cmd === 'screenshot') {
    var shot = screenshot(argv[1]);
    if (typeof shot === 'string') return shot;
    return JSON.stringify(shot, null, 2);
  }

  return 'usage: state | toggle | collapse | expand | menu-open | menu-dump | menu-key <n> | ' +
    'menu-select <n> | open-settings | open-settings-coord | window | window-dump | ' +
    'close-window | drag <idx> <dx> | screenshot [path]';
}
