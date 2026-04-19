---
description: Verify this project is devpanl-ready — runs every readiness check and reports green/yellow/red per item with actionable repairs.
---

Verify this project's DevPanel integration. Use the `devpanl-analyzer` subagent in **verify mode**:

- Re-run the readiness scan from `devpanl-readiness` skill.
- Diff the detected values against `.devpanlrc.json`, `CLAUDE.md` integration section, and every `.agents/<role>/SOUL.md`.
- For each readiness check, report ✓ / ⚠ / ✗ with the specific fix.

Do **not** modify files in this command — verify only. If repairs are needed, the user runs `/devpanl:init` to apply them.

End with one of:

- `✓ devpanl-ready — agents can be dispatched against this project.`
- `⚠ devpanl-ready with caveats — see warnings.`
- `✗ NOT devpanl-ready — fix red items first; jobs will fail.`
