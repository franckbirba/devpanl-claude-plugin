---
name: storybook-authoring
description: Use when writing UI components in any devpanl studio project. Defines where stories live, naming rules, import constraints, and how stories reach the shared catalogue at ui.devpanl.dev.
---

# Storybook authoring for devpanl projects

Every studio project (dev-panel, zeno, edms, candidat, …) publishes its
UI to a single shared Storybook at **https://ui.devpanl.dev**. Before
writing a new component, browse the catalogue. If a pattern exists, copy
its implementation into your project. Do not invent a second Button.

## Where stories live

At the root of the project repo, in `stories/`. Mirror the component
hierarchy:

    stories/
      tokens.mdx                (tokens doc, one per project)
      Button.stories.jsx
      forms/
        LoginForm.stories.jsx

## Naming

- Story titles use the project slug as the top-level category:
  `title: 'zeno/Button'` (not `'Button'`, not `'Components/Button'`).
- `shared/` is reserved for cross-project tokens + primitives that live
  in dev-panel's `stories-shared/`. Never write to `shared/` from a
  non-devpanel project.

## Import rule

A story imports components by **relative path from the same repo only**.

    // OK
    import { Button } from '../src/components/button.jsx';

    // NEVER
    import { Button } from '@devpanl/ui';
    import { Button } from '../../dev-panel/src/...';

Storybook is a catalogue, not a module graph. If you see a pattern in
another project's section, copy the code into your repo; do not try to
import across projects.

## How stories reach the catalogue

On every push to `main`, the repo's `.github/workflows/sync-stories.yml`
caller workflow rsyncs `stories/` into the shared volume. No manual
upload, no API, no dashboard button. Git is the source of truth.

To enable sync in a new project, add this file at
`.github/workflows/sync-stories.yml`:

    name: Sync stories
    on:
      push:
        branches: [main]
        paths: ['stories/**']
    jobs:
      sync:
        uses: franckbirba/dev-panel/.github/workflows/sync-stories.yml@main
        with:
          project-slug: <your-project-slug>
        secrets:
          SYNC_SSH_KEY: ${{ secrets.STORYBOOK_SYNC_SSH_KEY }}
          SYNC_HOST: ${{ secrets.VPS_HOST }}

The two secrets must exist on the caller repo. Ask in #infra if you
don't have them.

## Tokens

Every project's first story is `stories/tokens.mdx`, a table of the
project's colors, spacing, radii, and typography. Seed it from
`stories-shared/tokens.mdx` in dev-panel; only deviate with an explicit
reason recorded in the MDX.

## Don't

- Don't add a `package.json` or `node_modules/` under `stories/` — the
  Storybook container provides React and Storybook itself.
- Don't write stories that fetch live data from the API. Use fixtures.
- Don't commit screenshots alongside stories; Storybook renders the
  component directly.
