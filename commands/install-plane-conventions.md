---
description: Install the `plane-conventions` skill, the PreToolUse reminder hook, and the CLAUDE.md anchor in this project. Idempotent.
argument-hint: "[--with-plane-token]"
---

Install Plane conventions onto this project so all contributors (humans + agents) follow the same rules when writing to Plane: title format, taxonomy, lifecycle, description templates, operational procedures.

This command is **idempotent**: running it twice replaces the auto-managed sections of the skill in place, leaves your edits outside those markers untouched, and never duplicates the hook entry in `settings.json`.

## What gets installed

Inside the host project:

| Path                                              | Role                                                   |
|---------------------------------------------------|--------------------------------------------------------|
| `.claude/skills/plane-conventions/SKILL.md`       | Project-resolved copy of the conventions skill         |
| `.claude/hooks/plane-conventions-reminder.sh`     | PreToolUse reminder fired on Plane MCP write tools     |
| `.claude/settings.json`                           | PreToolUse hook entry merged in (existing keys kept)   |
| `CLAUDE.md`                                       | `## Plane conventions` anchor section appended         |

The skill is generic across all devpanl projects; the project-specific bits (Plane workspace, project id, modules autorisés, IDs cheatsheet) are substituted at install from `.devpanlrc.json` and — optionally — from a live Plane API call.

## 1. Preflight

The install script checks:

- `.devpanlrc.json` exists in the project root (otherwise: run `/devpanl:init` first).
- `jq` is on `$PATH` (used to read the rc and to merge `settings.json` atomically).

## 2. Resolve project metadata

Reads from `.devpanlrc.json`:

- `plane.project_id` → injected into the skill's §0 and IDs cheatsheet.
- `plane.workspace_slug` (or `plane.workspace`) → injected into URL + project header. Defaults to `devpanl` if absent.
- `github.repo` → injected into §0 and used as the project display name (last path segment).

Missing values are written as `__SET_ME__`; the install still succeeds and you finish by hand.

## 3. (Optional) Resolve Plane IDs from the API

If you want the skill's §1.1 modules table and §8 IDs cheatsheet auto-populated, export `PLANE_TOKEN` before running:

```bash
export PLANE_TOKEN=<your-plane-personal-token>
```

The script will hit:

- `GET /api/v1/workspaces/<workspace>/projects/<id>/states/`
- `GET /api/v1/workspaces/<workspace>/projects/<id>/modules/`
- `GET /api/v1/workspaces/<workspace>/projects/<id>/labels/`

…and inject the results between the `<!-- BEGIN_PLANE_IDS -->` / `<!-- END_PLANE_IDS -->` and `<!-- BEGIN_PLANE_MODULES -->` / `<!-- END_PLANE_MODULES -->` markers in the resolved `SKILL.md`. Running again refreshes those blocks in place.

If `PLANE_TOKEN` is not set, the placeholders are left as `__SET_ME__` and the user fills them by hand (or re-runs the command later with the token).

## 4. Run the script

Execute via Bash tool, streaming output verbatim:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" PROJECT_DIR="${CLAUDE_PROJECT_DIR}" \
  "${CLAUDE_PLUGIN_ROOT}/scripts/install-plane-conventions.sh"
```

If the user passes `--with-plane-token`, prompt once for the token (don't echo it) and prepend `PLANE_TOKEN=<value>` to the command. Otherwise run as-is and let the script pick up `PLANE_TOKEN` from the existing shell env if present.

## 5. Final report

The script prints its own summary. After it completes, also tell the user:

```
✓ plane-conventions installed.
  Files to commit:
    - .claude/skills/plane-conventions/SKILL.md
    - .claude/hooks/plane-conventions-reminder.sh
    - .claude/settings.json
    - CLAUDE.md
  Then run /devpanl:doctor to confirm the readiness check turns green.
```

If `PLANE_TOKEN` was not set, add:

```
ℹ︎ The skill's §1.1 (modules autorisés) and §8 (IDs cheatsheet) still
   contain __SET_ME__ placeholders. Either edit by hand from your Plane
   project, or re-run with PLANE_TOKEN exported to auto-populate.
```

Never commit. The user reviews the diff and commits themselves, same as `/devpanl:init`.

## Escalations

- **`.devpanlrc.json` missing or invalid** → tell the user to run `/devpanl:init` first; do not create one here.
- **`.claude/settings.json` exists but does not parse as JSON** → script aborts; do not touch the file. Tell the user to fix or move it aside, then re-run.
- **CLAUDE.md missing** → script skips the anchor and warns. Run `/devpanl:init` to create it, then re-run this command.
- **Hook already present** → script reports "already installed" for that step and moves on. Same for the anchor.
