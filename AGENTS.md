# AGENTS

## Workflow
- Do work in parallel when possible by utilizing subagents. Need to select the model wisely.
    - Opus4.8/GPT5.5 for high reasoning e.g. review, plan, high thinking
    - composer 2.5 non-fast for other simpler tasks

## Design Context

PeekBar is a native macOS menu-bar utility. Design register is **product** (design serves the app; be indistinguishable from macOS System Settings).

Before any UI or design work, read [`PRODUCT.md`](PRODUCT.md) for register, users, purpose, brand personality, anti-references, and design principles. Core principles: native by default, invisible until needed, teach the ⌘-drag setup well, instant & reliable, respect the user's attention (no nagging, no decorative motion).

For design/UI tasks, use the `impeccable` skill (`.cursor/skills/impeccable/`); it reads `PRODUCT.md` automatically.
