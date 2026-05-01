---
description: Wire this project's GlitchTip project to forward errors into the devpanel captures inbox. Idempotent — safe to re-run.
argument-hint: "[--team <slug>] [--project <slug>] [--bridge-url <url>]"
---

Register (or refresh) the `forward-to-devpanl` alert on the matching GlitchTip project so its events POST into the bridge endpoint at `POST /api/webhooks/glitchtip/:projectId`. Opt-in companion to `/devpanl:init` — never bolted into init, same as `/devpanl:add-storybook`.

This command is **idempotent**. If the alert already exists with the right URL, it prints "already wired" and exits clean. If the URL has drifted, it patches the alert in place. Otherwise it creates one.

## Recommended sequencing (read once)

This command wires the **alert side** only — events that already exist
in GlitchTip get forwarded into the captures inbox. For the host app to
*emit* events into GlitchTip in the first place, install the SDK first:

1. `/devpanl:install-glitchtip-sdk` — host app starts emitting events.
2. Trigger a real error (or send a test event) — verify it lands at `glitchtip.devpanl.dev`.
3. **`/devpanl:wire-glitchtip`** *(this command)* — alert forwards events from GlitchTip into the captures inbox.

Running them in the other order is fine but you'll see an empty alert until the SDK is in place.

## 0. Why the internal Docker URL (read once, then move on)

The plugin registers the webhook with the **internal Docker network URL**:

```
http://devpanel-api:3030/api/webhooks/glitchtip/<devpanl-project-id>?secret=<GLITCHTIP_BRIDGE_HMAC_SECRET>
```

Reason: Cloudflare WAF rule 1010 ("browser integrity check") blocks `glitchtip-worker` over `https://devpanl.dev/...` — the worker uses an empty/Python-default User-Agent and Cloudflare returns 403. Confirmed live during DEVPA-168: same payload fails 403 publicly, returns 201 over the internal URL. Both `glitchtip-worker` and `devpanel-api` live on the `devpanel_net` Docker network, so the call never leaves the host.

Auth uses the **`?secret=` querystring path**, not the HMAC header — GlitchTip's "Generic Webhook" recipient does NOT sign payloads. The URL itself is the bearer; treat it like a capability URL.

A working reference alert (`forward-to-devpanl` on GlitchTip project `smoke`, id=1) was left in place by DEVPA-168 — its URL pattern is the source of truth.

## 1. Resolve inputs

Resolve in this order, stop at the first hit per field. Do not ask the user any questions unless explicitly told to (interactive mode at the end if needed).

### 1a. devpanl project id (path segment in the bridge URL)

1. `.devpanlrc.json` → `plane.project_id` — required to wire anything.
2. If missing or `__SET_ME__`, abort with: `✗ plane.project_id not set in .devpanlrc.json — run /devpanl:init first.`

### 1b. GlitchTip team slug

1. `$ARGUMENTS` contains `--team <slug>`.
2. `.devpanlrc.json` → `glitchtip.team`.
3. Otherwise prompt the user **once**: `GlitchTip team slug for this project (e.g. core):` and then write the answer back to `.devpanlrc.json#glitchtip.team` so future runs skip this question.

### 1c. GlitchTip project slug

1. `$ARGUMENTS` contains `--project <slug>`.
2. `.devpanlrc.json` → `glitchtip.project_slug`.
3. Otherwise default to the same slug that `/devpanl:add-storybook` uses: lowercased last segment of `github.repo` (e.g. `franckbirba/zeno` → `zeno`), normalized to `[a-z0-9-]`. Prompt the user to confirm if not in `.devpanlrc.json` yet, and write back on confirmation.

### 1d. Bridge URL override

If `$ARGUMENTS` contains `--bridge-url <url>`, use it verbatim (escape-hatch for non-default deployments). Otherwise the script defaults to the internal Docker URL above.

## 2. Verify required env vars

Both must be present in the shell or the run will fail:

- `GLITCHTIP_API_TOKEN` — Bearer token from `glitchtip.devpanl.dev` Profile → Auth Tokens with `org:admin + project:admin + project:write` (DEVPA-168 step 6).
- `GLITCHTIP_BRIDGE_HMAC_SECRET` — same value that lives in services-VPS `.env.production` under `GLITCHTIP_BRIDGE_HMAC_SECRET`.

If either is missing, print:

```
✗ <var> not set. Source it from the agents-host secrets store and re-run.
```

…and stop. Do not proceed to the API call.

## 3. Run the wiring script

Execute the bundled script via Bash tool, streaming its output verbatim:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wire-glitchtip-alert.sh \
  --team <team> \
  --project <project> \
  --devpanl-project <devpanl-project-id>
```

Append `--bridge-url <url>` only when explicitly overridden.

The script:

- `GET /api/0/projects/devpanl-studio/<team>/alerts/` to list existing alerts.
- If `forward-to-devpanl` exists with the matching URL → exit clean.
- If it exists with a drifted URL → `PUT` to fix it.
- If it doesn't exist → `POST` to create it with body:
  ```json
  {
    "name": "forward-to-devpanl",
    "timespan_minutes": 1,
    "quantity": 1,
    "alertRecipients": [{"recipientType": "webhook", "url": "<bridge URL>"}]
  }
  ```

## 4. Patch `.devpanlrc.json`

After a successful run, write back any newly-resolved values so the next run is non-interactive:

```json
{
  "glitchtip": {
    "team": "<team>",
    "project_slug": "<project>"
  }
}
```

Merge into the existing file — never overwrite unrelated keys. If `.devpanlrc.json` doesn't exist, suggest the user run `/devpanl:init` first instead of creating it here.

## 5. Final report

Print a one-block summary, replacing the pieces actually run:

```
✓ glitchtip wired for <project>
   alert:        forward-to-devpanl (created | already wired | url patched)
   bridge URL:   http://devpanel-api:3030/api/webhooks/glitchtip/<id>?secret=***
   devpanl proj: <plane.project_id>
   glitchtip:    devpanl-studio/<team>/<project>

Next: trigger any error in the wired project; it should appear under
captures with source=glitchtip in the dashboard. Reference smoke alert
on glitchtip.devpanl.dev project `smoke` (id=1) confirms the path.
```

Do not commit. The user reviews the diff (only `.devpanlrc.json` should change locally) and commits themselves, same as `/devpanl:init`.
