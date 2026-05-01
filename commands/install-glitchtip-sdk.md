---
description: Install and wire a GlitchTip-compatible SDK (Sentry SDK) into this project so server and client errors flow into glitchtip.devpanl.dev. Interactive — touches source.
argument-hint: "[--server-only|--client-only] [--dsn <dsn>]"
---

Install the right Sentry SDK in this project and drop a minimal `Sentry.init` call so runtime errors land in `glitchtip.devpanl.dev`. Companion to `/devpanl:wire-glitchtip` (which only wires the alert recipient on the GlitchTip side).

This command is **interactive** — like `/devpanl:update-widget`, it modifies host source code. Show the diff and ask before writing.

## Recommended sequencing (read once)

1. `/devpanl:install-glitchtip-sdk` — host app starts emitting events to GlitchTip.
2. Trigger a real error (or send a test event) — verify it lands at `glitchtip.devpanl.dev` in the right project.
3. `/devpanl:wire-glitchtip` — alert forwards events from GlitchTip into the captures inbox.

Running them in the other order is fine but you'll see an empty alert until the SDK is in place.

## 0. Required reading

Re-read the `glitchtip-sdk-authoring` skill — that's the source of truth for which SDK, which init snippet, which env var, which file location per stack. This command is the executor; the skill is the spec.

## 1. Detect surfaces present

Per the skill's "Detection rules" section, decide which of these are present:

- **Server surface** — Node entrypoint, Express/Fastify/Koa/Hono, Next.js server, FastAPI/Flask/Django, Go `net/http`.
- **Client surface** — Vite + React, Next.js (covers both).

Honor `$ARGUMENTS`:

- `--server-only` → skip client even if detected.
- `--client-only` → skip server even if detected.

If neither surface is detected, print the skill's "no supported surface" message and stop.

## 2. Resolve the DSN once

Resolve in this order, stop at the first hit:

1. `$ARGUMENTS` contains `--dsn <dsn>`.
2. `.devpanlrc.json` → `glitchtip.dsn`.
3. Prompt the user **once**:
   ```
   GlitchTip DSN (https://<key>@glitchtip.devpanl.dev/<num>):
   ```
   Empty input → abort with: `✗ DSN required. Get it from glitchtip.devpanl.dev → project → Settings → SDK Setup, then re-run.`

After resolution, write the DSN back to `.devpanlrc.json#glitchtip.dsn` (merge into existing file, never overwrite unrelated keys; if the file does not exist, abort and tell the user to run `/devpanl:init` first).

## 3. Per-surface install (one section per detected surface)

For each detected surface, in order: **server first, then client**.

### 3a. Show the plan

Tell the user, in chat, what is about to happen — explicit per surface:

```
Server surface: Node + Express
- install:    npm i @sentry/node            (lockfile-aware)
- create:     src/instrument.js
- patch:      src/index.js (add `import "./instrument.js";` as the first line)
- patch:      src/index.js (add Sentry.Handlers.requestHandler / errorHandler)
- patch:     .env.example  (add GLITCHTIP_DSN=)
```

```
Client surface: Vite + React
- install:    npm i @sentry/react           (lockfile-aware)
- create:     src/instrument.js
- patch:      src/main.jsx (import + Sentry.ErrorBoundary wrap)
- patch:     .env.example  (add VITE_GLITCHTIP_DSN=)
```

### 3b. Already-installed check

For each surface, before any change:

- The SDK package is already a dependency, AND
- An `instrument.{js,ts}` (or stack equivalent) already contains a `Sentry.init` call referencing the right env var.

If both are true, print `skip <surface> (already installed)` and move on without writing anything.

### 3c. Confirm before writing

Single confirmation per surface (not per file). On "no", skip the surface and move on to the next.

### 3d. Apply

Execute the steps from the skill's per-stack template, in order:

1. Install the SDK via the project's package manager (detect from lockfile: `pnpm-lock.yaml` → `pnpm`, `yarn.lock` → `yarn`, `bun.lockb` → `bun`, default → `npm`; for Python use `pip` + patch `requirements.txt` / `pyproject.toml` if present; for Go use `go get`). Stream the install output.
2. `Write` the `instrument.{js,ts}` (or stack equivalent) file. Refuse to overwrite if it already exists with non-template content — surface as `⚠ instrument.js exists with custom content — review by hand`.
3. `Edit` the entrypoint to add the import as the **first** line. Use exact-match before/after; do not reformat the file.
4. (Express/server only) `Edit` to add `requestHandler` and `errorHandler` middlewares — only if `express` is in deps.
5. `Edit` `.env.example` to append the right env var with an empty value. If `.env.example` doesn't exist, skip and warn (per skill).
6. Re-read every modified file and confirm syntax (one-line balance check is enough — real typecheck runs in CI).

### 3e. Patch CLAUDE.md

Append (or update) a `## GlitchTip SDK` section under the existing `## DevPanel integration` section. Use the exact subheading so `/devpanl:doctor` can find it:

```markdown
## GlitchTip SDK

- Server SDK: `@sentry/node` (init at `src/instrument.js`)  *(omit line if no server surface)*
- Client SDK: `@sentry/react` (init at `src/instrument.js`)  *(omit line if no client surface)*
- Server DSN env: `GLITCHTIP_DSN`                           *(omit if no server surface)*
- Client DSN env: `VITE_GLITCHTIP_DSN`                       *(omit if no client surface)*
- DSN value cached at: `.devpanlrc.json#glitchtip.dsn`
```

If the section already exists, replace its body with the freshly resolved values.

## 4. Final report

One block summary per surface, then next-step pointer:

```
✓ GlitchTip SDK installed
   server:   @sentry/node @ src/instrument.js  (env: GLITCHTIP_DSN)
   client:   @sentry/react @ src/instrument.js (env: VITE_GLITCHTIP_DSN)
   .env.example patched (DSN keys added, no value)

Next:
  1. Set GLITCHTIP_DSN / VITE_GLITCHTIP_DSN in .env (gitignored) — same DSN
     value works for both. Cached in .devpanlrc.json#glitchtip.dsn.
  2. Restart the dev server, throw a test error, confirm it appears at
     https://glitchtip.devpanl.dev/devpanl-studio/<project>/issues/.
  3. Run /devpanl:wire-glitchtip to forward those events to the captures
     inbox in DevPanel.
```

If any surface was skipped due to "already installed" or "user said no", reflect that in the report (`skip server (already installed)` / `skip client (declined)`).

## Escalations

- **Multiple entrypoints detected** (e.g. both `src/index.js` and `src/server.js`) → list them, ask which is runtime, do not guess.
- **TypeScript strict project** → drop `instrument.ts` (matching template adapted) instead of `.js`.
- **Unsupported framework** (Vue, Svelte, Remix today) → print the skill's pointer to Sentry docs for that framework and continue with the other surface if any.
- **Existing custom `Sentry.init`** that doesn't reference the right env var → leave it alone, surface as `⚠ existing Sentry.init found, not modified — verify it points at glitchtip.devpanl.dev`.

Never commit. The user reviews the diff and commits themselves, same as `/devpanl:init` and `/devpanl:update-widget`.
