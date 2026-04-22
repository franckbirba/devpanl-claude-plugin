---
description: Make this project devpanl-ready in one silent pass — generates .agents souls, .devpanlrc.json, .mcp.json entries, and the CLAUDE.md integration section.
---

Make this project ready for the DevPanel autonomous agent team.

Use the `devpanl-analyzer` subagent. Do not ask any questions — silent mode. Detect everything from the codebase, fall back to `__SET_ME__` for unresolvable values and surface them in the final report.

Output the analyzer's "generated / needs attention / doctor checks" report at the end. After that, do nothing else — the user reviews the diff with git and decides what to commit.

## Scaffold Storybook authoring

Agents and humans in this project will author stories in `stories/`. The
catalogue lives at https://ui.devpanl.dev and pulls stories on every
push to main.

1. Create `stories/.keep` if `stories/` does not yet exist, so git
   tracks the folder even empty.

2. Create `.github/workflows/sync-stories.yml` with:

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
      project-slug: <PROJECT-SLUG>
    secrets:
      SYNC_SSH_KEY: ${{ secrets.STORYBOOK_SYNC_SSH_KEY }}
      SYNC_HOST: ${{ secrets.VPS_HOST }}
```

Replace `<PROJECT-SLUG>` with the same slug used everywhere else in
`.devpanlrc.json` (lowercase, hyphen-safe, ≤ 30 chars).

3. Print a reminder for the human that the two repo secrets
   `STORYBOOK_SYNC_SSH_KEY` and `VPS_HOST` must be provisioned before
   the first push to main.
