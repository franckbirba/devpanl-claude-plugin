---
name: widget-integration
description: How to wire the @devpanel/react widget into a host app, including the `user` prop so captures are attributable. Used by /devpanl:update-widget and referenced from /devpanl:init / /devpanl:doctor.
---

# Widget integration

The `@devpanel/react` widget posts captures (bug reports, feature requests) from inside the host app to the DevPanel control plane. As of spec `2026-04-24-widget-reporter-identity-design.md`, the widget accepts an optional `user` prop so reports carry the authenticated user's identity. Without `user`, reports are anonymous — fine for EDMS-style single-user apps, a triage headache for multi-user apps like Zeno.

## The target shape

```jsx
import { DevPanel } from '@devpanel/react';

<DevPanel
  apiUrl={import.meta.env.VITE_DEVPANEL_URL}
  apiKey={import.meta.env.VITE_DEVPANEL_API_KEY}
  user={authUser ? { id: authUser.id, name: authUser.name, email: authUser.email } : null}
/>
```

Rules:

- `user` is a plain object or `null`. Array / scalar is rejected by the server (400).
- Understood fields: `id`, `name`, `email` — stored in dedicated columns, filterable in the dashboard.
- Any other fields (e.g. `role`, `team`) are preserved in `reporter_extra` JSON.
- Passing `null` is the same as omitting `user`: all reporter columns stay null. Use that while auth is loading.
- Memoize the user object (`useMemo`) when the host re-renders a lot — otherwise the `postCapture` `useCallback` invalidates every render.

## Detecting the right auth source

Common patterns by stack:

| Stack marker | Hook / call | Usual shape |
|---|---|---|
| `@auth0/auth0-react` | `useAuth0()` → `user` | `{ sub, name, email, picture }` → map `sub` → `id` |
| `next-auth` (React) | `useSession()` → `data.user` | `{ id?, name, email, image }` |
| `@clerk/clerk-react` | `useUser()` → `user` | `{ id, primaryEmailAddress.emailAddress, fullName }` |
| `@supabase/auth-helpers-react` | `useUser()` or `useSession()` | `{ id, email, user_metadata.name }` |
| `lucia` | custom context (`useAuth()` or similar) | project-defined |
| `firebase/auth` | `onAuthStateChanged` or `useAuthState` (react-firebase-hooks) | `{ uid, displayName, email }` → map `uid` → `id` |
| Home-grown context | `useUser()`, `useCurrentUser()` | project-defined |

If none of the above match, grep the host app for `user`, `currentUser`, `session` context providers and trust the closest one to the widget mount.

## The update flow (used by `/devpanl:update-widget`)

1. **Locate the mount.** `Grep -n '<DevPanel' src/ app/ pages/ components/` — pick the first match (usually `App.jsx`, `layout.tsx`, or `_app.tsx`).
2. **Read the file.** Record the existing props.
3. **Already wired?** If the mount already passes `user=`, report "already wired" and stop.
4. **Detect the auth source** (table above, or fallback to nearest user-like context).
5. **Draft the diff.** Show the proposed before/after JSX in the chat. Keep it minimal: add the import if needed, derive `user` from the chosen hook, pass it into the mount. Leave everything else (apiUrl, apiKey, position, getState) alone.
6. **Ask for confirmation before writing.** The update command is NOT silent — unlike `/devpanl:init`, this touches source code.
7. **Apply with `Edit`.** Single targeted edit; do not reformat the surrounding file.
8. **Verify.** Re-read the file and confirm the final JSX parses (one line `grep`-check for balanced braces is enough — a real typecheck lives in the project's own CI).
9. **Report.** One-line summary of what changed and next steps ("commit when happy; dashboard will start showing the reporter name after the app redeploys").

## Failure modes to call out explicitly

- **No mount found.** Tell the user — nothing to do.
- **Multiple mounts.** Unusual. Report all of them, ask which one to update.
- **No detectable auth source.** Don't guess — output the target JSX with a `__SET_ME__` comment and tell the user to wire it by hand. Example:
  ```jsx
  user={/* __SET_ME__: replace with your auth user, e.g. useAuth().user */ null}
  ```
- **TypeScript project with strict `User` type.** If the host has its own `User` interface that doesn't match `{ id, name, email }`, adapt at the mount site — don't widen the host's type.

## What NOT to do

- Don't refactor the auth setup. If the host's auth hook is awkward, that's the host's problem.
- Don't introduce a new context provider, hook, or utility file just to serve the widget. One inline object literal at the mount is enough.
- Don't edit files outside the mount file unless a new import is strictly required.
- Don't commit. Leave git to the user, like `/devpanl:init` does.
