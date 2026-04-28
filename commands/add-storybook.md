---
description: Onboard this project to ui.devpanl.dev — scaffold stories/, the sync workflow, and the UI section in CLAUDE.md. Idempotent.
---

Wire this project into the shared Storybook catalogue at https://ui.devpanl.dev. Opt-in companion to `/devpanl:init` — never bolted into init.

This command is **idempotent**: running it twice is safe. For each step, detect what already exists and either skip it or print what's already there.

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

## 5. Repo secrets reminder

Print this at the end, every run (it's cheap and easy to miss):

```
Repo secrets required for sync to succeed on the next push to main:
  - STORYBOOK_SYNC_SSH_KEY
  - VPS_HOST
Set them in GitHub → Settings → Secrets and variables → Actions.
```

## 6. Final report

Print a compact summary, one line per artefact, prefixed with `create` / `skip` / `warn`. End with the catalogue URL:

```
✓ storybook wired — stories will sync to https://ui.devpanl.dev/<slug>/ on next push to main.
```

If any step printed `warn`, end with:

```
⚠ storybook partially wired — see warnings above.
```

Do not commit. The user reviews the diff and commits themselves, same as `/devpanl:init`.
