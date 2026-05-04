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

GlitchTip wiring is **not** part of init either — it's opt-in (DEVPA-170), split in two halves so server-only or client-only projects can pick what they need:

- `/devpanl:install-glitchtip-sdk` — drops a Sentry-compat SDK in the host source so server and/or client errors emit to `glitchtip.devpanl.dev`. Interactive (touches source).
- `/devpanl:wire-glitchtip` — registers the `forward-to-devpanl` alert recipient on the GlitchTip side so events flow into the captures inbox. Idempotent (no source touched).

Mention them in the final report only when missing:

```
ℹ︎ This project has no GlitchTip SDK installed (no @sentry/* in deps). Run /devpanl:install-glitchtip-sdk to start emitting errors.
ℹ︎ This project's GlitchTip is not yet wired to the captures inbox. Run /devpanl:wire-glitchtip to forward events.
```

Plane conventions wiring is **not** part of init either — opt-in to keep init silent. Mention it in the final report when `.claude/skills/plane-conventions/SKILL.md` does not exist:

```
ℹ︎ This project has no Plane conventions skill installed. Run /devpanl:install-plane-conventions to enforce uniform Plane usage across the team (humans + agents).
```
