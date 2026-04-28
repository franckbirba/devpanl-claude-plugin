---
description: Make this project devpanl-ready in one silent pass — generates .agents souls, .devpanlrc.json, .mcp.json entries, and the CLAUDE.md integration section.
---

Make this project ready for the DevPanel autonomous agent team.

Use the `devpanl-analyzer` subagent. Do not ask any questions — silent mode. Detect everything from the codebase, fall back to `__SET_ME__` for unresolvable values and surface them in the final report.

Output the analyzer's "generated / needs attention / doctor checks" report at the end. After that, do nothing else — the user reviews the diff with git and decides what to commit.

Storybook scaffolding is **not** part of init — it's opt-in via `/devpanl:add-storybook`. Mention it in the final report only if the project does not yet have `stories/` or `.github/workflows/sync-stories.yml`:

```
ℹ︎ This project is not yet wired to ui.devpanl.dev. Run /devpanl:add-storybook to onboard.
```
