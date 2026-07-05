# AGENTS

## Workflow
- Do work in parallel when possible by utilizing subagents. Need to select the model wisely.
    - Opus4.8/GPT5.5 for high reasoning e.g. review, plan, high thinking
    - composer 2.5 non-fast for other simpler tasks
- Gradually commit finished task as a checkpoint. It should be meaningful work and it would be scoped to specific chunk of work. Never commit everything including unrelated things in one commit.
- Only reviewed changes may be committed. Route **every** commit — inside super-exec or any ad-hoc / out-of-workflow commit — through `/se-commit`; never `git commit` directly. `/se-commit` is the enforcement **gate**, not the reviewer: before committing, the committer must have reviewed the staged files (or, when there is no review evidence — e.g. an ad-hoc checkpoint commit outside `/se-exec`'s per-task build loop — spawned one or two fresh reviewer subagents over the staged diff, applying `/se-review`'s severity model and resolving Critical/Important). `/se-commit` refuses/stops if the staged paths were not reviewed; the committer, who holds the change's intent, does the actual reviewing. Once fixed, meaning that new code hasn't been reviewed so need to trigger review again.
- UI testing/verification should be done by subagents to protect the primary agent context window.

## Verification & UI Testing

The `peekbar-ui-testing` skill (`.cursor/skills/peekbar-ui-testing/`) drives and asserts PeekBar's real menu-bar UI (toggle click, Ctrl-click context menu, ⌘-drag reposition, Settings window) through the `macos_automator` MCP. Use it to verify menu-bar behavior against the running app.

During planning, always consider this skill for the verification step: when a task touches the status item, hiding/collapse, the context menu, ⌘-drag ordering, or the Settings window, integrate concrete `peekbar-ui-testing` checks into the plan as its acceptance/verification criteria (alongside unit tests), rather than relying on manual checking.

## Keep spec in sync
- Any requested behavioral change by user should update existing spec as well.
- The spec should contain the intention, direction, expected experience, it should not contain detail code or implementation.


## Design Context

PeekBar is a native macOS menu-bar utility. Design register is **product** (design serves the app; be indistinguishable from macOS System Settings).

Before any UI or design work, read [`PRODUCT.md`](PRODUCT.md) for register, users, purpose, brand personality, anti-references, and design principles. Core principles: native by default, invisible until needed, teach the ⌘-drag setup well, instant & reliable, respect the user's attention (no nagging, no decorative motion).

For design/UI tasks, use the `impeccable` skill (`.cursor/skills/impeccable/`); it reads `PRODUCT.md` automatically.
