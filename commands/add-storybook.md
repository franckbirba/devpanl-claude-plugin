---
description: Onboard this project to ui.devpanl.dev — scaffold stories/, the sync workflow, set GitHub secrets. Idempotent.
argument-hint: "[--skip-secrets]"
---

Wire this project into the shared Storybook catalogue at https://ui.devpanl.dev. Opt-in companion to `/devpanl:init` — never bolted into init.

This command is **idempotent**: running it twice is safe. For each step, detect what already exists and either skip it or print what's already there.

If `$ARGUMENTS` contains `--skip-secrets`, skip step 6 (secret provisioning) and only print a reminder. Default behavior is to provision the secrets automatically.

## 1. Resolve the project slug

Resolve `<slug>` in this order, stop at the first hit. Do not ask the user any questions.

1. `.devpanlrc.json` → `plane.workspace_slug` is the workspace, not the project. Use `github.repo` last segment instead: split on `/`, take the second half. Example `franckbirba/zeno` → `zeno`.
2. If no `.devpanlrc.json`, fall back to `git remote get-url origin` last path segment, stripped of `.git`.
3. If no git remote, fall back to the basename of the current working directory.

Normalize: lowercase, replace any non `[a-z0-9-]` with `-`, collapse repeats, trim to ≤ 30 chars. Print the resolved slug at the start of the run.

## 2. Scaffold `stories/`

Conventions come from the `storybook-authoring` skill — re-read it before writing files if unsure. The shared Storybook container provides React + Storybook, so do **not** create `package.json`, `node_modules/`, or `.storybook/` under `stories/`.

Create only what is missing:

- `stories/.keep` — empty marker so git tracks the folder.
- `stories/tokens.mdx` — seed with the project header below; humans fill in the tables later.
- `stories/Button.stories.jsx` — minimal starter story so the catalogue shows something on first sync.

`stories/tokens.mdx` template (replace `<slug>`):

```mdx
import { Meta } from '@storybook/blocks';

<Meta title="<slug>/tokens" />

# <slug> design tokens

Document this project's colors, spacing, radii, and typography here.
Seed from `stories-shared/tokens.mdx` in dev-panel; deviations need a
short rationale recorded inline.
```

`stories/Button.stories.jsx` template (replace `<slug>`):

```jsx
export default {
  title: '<slug>/Button',
  parameters: { layout: 'centered' },
};

export const Primary = {
  render: () => (
    <button
      style={{
        padding: '8px 16px',
        borderRadius: 6,
        border: 'none',
        background: '#111',
        color: '#fff',
        cursor: 'pointer',
      }}
    >
      Primary
    </button>
  ),
};
```

If any of these files already exist, leave them alone and print `skip <path> (exists)`.

## 3. Drop `.github/workflows/sync-stories.yml`

Create `.github/workflows/sync-stories.yml` if missing. If it already exists, read it: if it already calls `franckbirba/dev-panel/.github/workflows/sync-stories.yml@main` with the right slug, print `skip workflow (already wired)`. Otherwise leave the existing file alone and print `⚠ workflow exists but does not match expected pattern — review manually`.

Template (replace `<slug>`):

```yaml
name: Sync stories

on:
  push:
    branches: [main]
    paths: ['stories/**']
  workflow_dispatch:

jobs:
  sync:
    uses: franckbirba/dev-panel/.github/workflows/sync-stories.yml@main
    with:
      project-slug: <slug>
    secrets:
      SYNC_SSH_KEY: ${{ secrets.STORYBOOK_SYNC_SSH_KEY }}
      SYNC_HOST: ${{ secrets.VPS_HOST }}
```

## 4. Patch `CLAUDE.md`

If `CLAUDE.md` does not exist, create it with just the UI section. If it exists and already contains a `## UI catalogue` heading, leave it alone and print `skip CLAUDE.md (UI section present)`. Otherwise append (single trailing newline before, one after) the block below — replace `<slug>`:

```markdown
## UI catalogue

Stories for this project are published to https://ui.devpanl.dev/<slug>/
on every push to `main` (see `.github/workflows/sync-stories.yml`).

Authoring rules live in the `storybook-authoring` skill (devpanl plugin).
TL;DR:

- Stories live in `stories/` at the repo root.
- `title` always starts with `<slug>/` (e.g. `<slug>/Button`).
- Imports are relative to this repo only — never reach across projects.
- The shared container provides React and Storybook; don't add a local
  `package.json` under `stories/`.
```

## 5. Capture the VPS host once per machine

Read `~/.devpanl/vps-host`. If it exists, print `vps host: <value> (cached)` and skip to step 6.

If it does not exist:

1. Ask the user **once**: `VPS host for ui.devpanl.dev (e.g. deploy@ui.devpanl.dev):`
2. Write the answer to `~/.devpanl/vps-host` (creating `~/.devpanl/` with `mkdir -p` if needed).
3. Print `vps host: <value> (cached at ~/.devpanl/vps-host — future projects won't ask)`.

This is the only question the command ever asks, and only once per machine. Every subsequent `/devpanl:add-storybook` on this machine reuses the cached value.

## 6. Provision GitHub Actions secrets automatically

Skip this step entirely if `$ARGUMENTS` contains `--skip-secrets` — print a one-line reminder pointing at `${CLAUDE_PLUGIN_ROOT}/scripts/wire-storybook-secrets.sh` and move on.

Otherwise, preflight: check that `gh` and `ssh` are on `$PATH` and that `gh auth status` succeeds. If any check fails, **do not error** — print:

```
⚠ skipping automatic secret provisioning: <missing tool or gh not authenticated>
  Fix and re-run, or run manually:
    bash ${CLAUDE_PLUGIN_ROOT}/scripts/wire-storybook-secrets.sh
```

…and continue to step 7.

If preflight passes, run the bundled script directly via Bash tool:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wire-storybook-secrets.sh
```

The script:

- Reads `~/.devpanl/vps-host` (cached value from step 5 — no prompt).
- Generates `~/.devpanl/keys/storybook_sync_<slug>` if it doesn't exist; reuses it if it does.
- Appends the public key to the VPS `~/.ssh/authorized_keys` (skips if already there).
- Sets `STORYBOOK_SYNC_SSH_KEY` and `VPS_HOST` as repo secrets via `gh secret set`.

Stream the script's output verbatim so the user sees what happened. If the script exits non-zero, surface its last 20 lines and tell the user to re-run with `--skip-secrets` if they want to proceed without secrets.

## 7. Final report

Print a compact summary, one line per artefact, prefixed with `create` / `skip` / `warn`. Then end with one of these, depending on what happened in step 6:

- Secrets provisioned cleanly:

  ```
  ✓ storybook wired — push to main and stories sync to https://ui.devpanl.dev/<slug>/.
  ```

- Secrets skipped (--skip-secrets, or preflight failed):

  ```
  ⚠ storybook scaffolded but secrets not provisioned — run:
      bash ${CLAUDE_PLUGIN_ROOT}/scripts/wire-storybook-secrets.sh
    then push to main.
  ```

- Any other step printed `warn`:

  ```
  ⚠ storybook partially wired — see warnings above.
  ```

Do not commit. The user reviews the diff and commits themselves, same as `/devpanl:init`.
