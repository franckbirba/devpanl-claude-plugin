---
name: glitchtip-sdk-authoring
description: How to install and configure a GlitchTip-compatible SDK (Sentry SDK) in a host project so server and client errors flow into glitchtip.devpanl.dev. Used by /devpanl:install-glitchtip-sdk and referenced from /devpanl:wire-glitchtip / /devpanl:doctor.
---

# GlitchTip SDK authoring

GlitchTip is wire-compatible with Sentry: every Sentry SDK works without code changes, only the DSN changes (point at `glitchtip.devpanl.dev`). This skill is the source of truth for *what* to install, *where* to drop the init call, and *what env var* carries the DSN per stack.

The complement to this skill is `/devpanl:wire-glitchtip`, which registers the alert recipient on the GlitchTip side. Recommended sequencing:

1. `/devpanl:install-glitchtip-sdk` — host app starts emitting events to GlitchTip.
2. Trigger a real error or send a test event — verify it lands in `glitchtip.devpanl.dev`.
3. `/devpanl:wire-glitchtip` — alert forwards events from GlitchTip into the captures inbox.

## DSN strategy

Each GlitchTip project exposes one DSN of the shape:

```
https://<public-key>@glitchtip.devpanl.dev/<project-num>
```

The same DSN works for server and client SDKs (Sentry-compat, public-key only). **Cache it once** in `.devpanlrc.json#glitchtip.dsn` after the first install. Future `/devpanl:install-glitchtip-sdk` runs (e.g. adding the SDK to a sibling surface) reuse it without prompting.

Per-surface env-var conventions:

| Surface              | Env var                       | Build-time? | Notes                                                |
| -------------------- | ----------------------------- | ----------- | ---------------------------------------------------- |
| Node / Express       | `GLITCHTIP_DSN`               | runtime     | read by `process.env.GLITCHTIP_DSN`                  |
| Vite browser         | `VITE_GLITCHTIP_DSN`          | build-time  | inlined by Vite; safe to expose (DSN is public-key) |
| Next.js browser      | `NEXT_PUBLIC_GLITCHTIP_DSN`   | build-time  | inlined by Next; same reasoning                     |
| Next.js server       | `GLITCHTIP_DSN`               | runtime     | server runtime + edge runtime                        |
| Python (FastAPI/Django/Flask) | `GLITCHTIP_DSN`      | runtime     | read by `os.environ["GLITCHTIP_DSN"]`               |
| Go                   | `GLITCHTIP_DSN`               | runtime     | `os.Getenv`                                          |

Always patch `.env.example` with the empty key (`GLITCHTIP_DSN=` etc.) — never write the real DSN there. The real value goes in `.env` (gitignored) or the deploy host's secret store.

## Per-stack install templates

For each entry: package, install command, init code, where to drop it. The command runs the install, drops the file/edit, and patches `.env.example`. It does **not** run the project — the user verifies and commits.

### Node entrypoint (plain Node / Express / Fastify)

- Package: `@sentry/node` (also covers Express/Fastify via auto-instrumentation).
- Install: `npm i @sentry/node` (swap `npm` → `pnpm`/`yarn` per lockfile, same as analyzer rules).
- Drop file: `src/instrument.js` (or `src/instrument.ts` if `tsconfig.json` exists). This file MUST run before any other import in the entrypoint. Sentry's docs are non-negotiable on the order.

```js
// src/instrument.js — must be required FIRST in the entrypoint.
import * as Sentry from "@sentry/node";

if (process.env.GLITCHTIP_DSN) {
  Sentry.init({
    dsn: process.env.GLITCHTIP_DSN,
    environment: process.env.NODE_ENV || "development",
    tracesSampleRate: 0,         // GlitchTip OSS: tracing not yet supported
    profilesSampleRate: 0,
  });
}
```

- Patch the entrypoint (`src/index.js`, `server.js`, etc.) so the very first line is:
  ```js
  import "./instrument.js";
  ```
  …or the CommonJS equivalent `require("./instrument.js");`. Place it above every other import — including framework imports — or async errors before init won't be captured.

- For Express: also add the request handler **before** routes and the error handler **after**:
  ```js
  app.use(Sentry.Handlers.requestHandler());
  // routes
  app.use(Sentry.Handlers.errorHandler());
  ```
  Only add these if `express` is in `package.json#dependencies`. Skip if Fastify/Koa/Hono — those have their own hooks.

### Vite + React (browser)

- Package: `@sentry/react`.
- Install: `npm i @sentry/react` (lockfile-aware, as above).
- Drop file: `src/instrument.js` (next to `main.jsx` or `main.tsx`).

```js
// src/instrument.js
import * as Sentry from "@sentry/react";

if (import.meta.env.VITE_GLITCHTIP_DSN) {
  Sentry.init({
    dsn: import.meta.env.VITE_GLITCHTIP_DSN,
    environment: import.meta.env.MODE,
    tracesSampleRate: 0,
    integrations: [],
  });
}
```

- Patch `src/main.jsx` (or `main.tsx`): the very first import is `import "./instrument";`. Wrap the root in `Sentry.ErrorBoundary` so render-time React errors are caught:
  ```jsx
  import "./instrument";
  import * as Sentry from "@sentry/react";
  // …
  <Sentry.ErrorBoundary fallback={<p>Something went wrong.</p>}>
    <App />
  </Sentry.ErrorBoundary>
  ```
  If the project already has its own ErrorBoundary, do NOT replace it — wrap *inside* the existing one (Sentry's boundary still reports to GlitchTip even when a parent boundary swallows the error).

### Next.js (App Router and Pages Router)

- Package: `@sentry/nextjs`.
- Install: `npm i @sentry/nextjs`.
- Drop three files at repo root:
  - `sentry.server.config.js`
  - `sentry.client.config.js`
  - `sentry.edge.config.js`

```js
// sentry.server.config.js
import * as Sentry from "@sentry/nextjs";
if (process.env.GLITCHTIP_DSN) {
  Sentry.init({ dsn: process.env.GLITCHTIP_DSN, tracesSampleRate: 0 });
}
```

```js
// sentry.client.config.js
import * as Sentry from "@sentry/nextjs";
if (process.env.NEXT_PUBLIC_GLITCHTIP_DSN) {
  Sentry.init({ dsn: process.env.NEXT_PUBLIC_GLITCHTIP_DSN, tracesSampleRate: 0 });
}
```

```js
// sentry.edge.config.js
import * as Sentry from "@sentry/nextjs";
if (process.env.GLITCHTIP_DSN) {
  Sentry.init({ dsn: process.env.GLITCHTIP_DSN, tracesSampleRate: 0 });
}
```

- Patch `next.config.js`/`next.config.mjs` to wrap the export with `withSentryConfig` only if the user agrees — it's invasive (rewrites source maps). Default to **skip** the wrapper; init in three configs is enough for runtime capture.

### Python — FastAPI / Flask / Django

- Package: `sentry-sdk`.
- Install: `pip install sentry-sdk` (or add to `pyproject.toml` / `requirements.txt` per lockfile).

```python
# at the top of your app entrypoint, before the framework import
import os
import sentry_sdk

if os.environ.get("GLITCHTIP_DSN"):
    sentry_sdk.init(
        dsn=os.environ["GLITCHTIP_DSN"],
        traces_sample_rate=0.0,
    )
```

Drop into the project's main module: FastAPI → wherever `FastAPI()` is instantiated; Flask → wherever `Flask(__name__)` is; Django → top of `settings.py`.

### Go (net/http and friends)

- Package: `github.com/getsentry/sentry-go`.
- Install: `go get github.com/getsentry/sentry-go`.

```go
// in main.go, before serving:
import "github.com/getsentry/sentry-go"

func main() {
    if dsn := os.Getenv("GLITCHTIP_DSN"); dsn != "" {
        if err := sentry.Init(sentry.ClientOptions{Dsn: dsn}); err != nil {
            log.Printf("sentry init: %v", err)
        }
        defer sentry.Flush(2 * time.Second)
    }
    // …existing main…
}
```

For HTTP servers, optionally wrap handlers with `sentryhttp.New(...).Handle(mux)` — only do this if asked, it's a wrapping decision the host project should own.

## Detection rules (used by `/devpanl:install-glitchtip-sdk`)

Stop at the first match per surface.

**Server surface present?**

- `package.json` exists → check `dependencies` for `express`, `fastify`, `koa`, `hono`, `@hapi/hapi`, `next` (server runtime), or any `bin/`-scripted entry — Node server.
- `pyproject.toml` / `requirements.txt` lists `fastapi` / `flask` / `django` / `starlette` — Python server.
- `go.mod` and `main.go` exists with a `net/http` import — Go server.

**Client surface present?**

- `package.json#dependencies` includes `react` AND `vite` is in `devDependencies` → Vite + React browser surface.
- `package.json#dependencies` includes `next` → Next.js (covers both, use the Next template).
- Any other framework (Vue, Svelte, Remix) → out of scope for now; print:
  ```
  ⚠ <framework> client SDK install not yet templated — see https://docs.sentry.io/platforms/javascript/guides/<framework>/ and wire by hand.
  ```
  …then continue with whatever else was detected.

If neither surface matches, print:

```
ℹ︎ No supported server or client surface detected. Skipping SDK install — only /devpanl:wire-glitchtip is needed for runtime forwarding (alert side only).
```

## Failure modes to call out explicitly

- **Already installed.** If the SDK package is in `package.json`/`pyproject.toml` AND an `instrument.js` (or equivalent) exists with a `Sentry.init` call, report "already installed for <surface>" and skip that surface. Do NOT re-edit.
- **Multiple entrypoints.** If both `src/index.js` and `src/server.js` exist, list them and ask which one is the runtime entrypoint. Don't guess.
- **DSN unknown.** If `.devpanlrc.json#glitchtip.dsn` is missing, prompt:
  ```
  GlitchTip DSN for this project (from glitchtip.devpanl.dev → project → Settings → SDK Setup):
  ```
  Cache the answer in `.devpanlrc.json` immediately. Empty input → abort with a fix-path message.
- **TypeScript strict project.** Drop `instrument.ts` instead of `.js` and import accordingly. If `tsconfig.json` has `"strict": true`, also add `as const` / non-null guards as needed — the templates above are JS-shaped intentionally.
- **No `.env.example`.** Don't create one — host project may be intentionally without it. Just skip the env patch and surface in the report:
  ```
  ⚠ no .env.example found — set GLITCHTIP_DSN= manually in your env config.
  ```

## What NOT to do

- Don't introduce sourcemap upload, release tagging, or `withSentryConfig` wrappers automatically. Those are invasive build-system changes; surface them as opt-ins in the final report.
- Don't enable tracing (`tracesSampleRate > 0`). GlitchTip OSS does not yet store traces; events with traces still ingest fine but the data is dropped server-side. Setting it to 0 saves bandwidth and avoids a confusing UI ("traces" tab empty).
- Don't add `@sentry/profiling-node` or browser performance integrations. Same reason as above.
- Don't write the real DSN into version-controlled files. Only `.env.example` (placeholder) and `.devpanlrc.json#glitchtip.dsn` (cached for future plugin runs, not read by the app).
- Don't refactor existing logging / error handling. Sentry coexists with `console.error`, Winston, pino, etc.
- Don't commit. The user reviews the diff and commits themselves.
