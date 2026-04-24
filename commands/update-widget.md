---
description: Wire (or re-wire) the @devpanel/react widget `user` prop to the host app's auth so captures carry reporter identity.
---

Upgrade the DevPanel widget in this project so it forwards the authenticated user to the dashboard.

Follow the `widget-integration` skill step-by-step:

1. Locate the `<DevPanel` mount via `Grep -n`.
2. Read the mount file. If `user=` is already present, report "already wired" and stop — do nothing.
3. Detect the auth source (see the stack table in the skill).
4. Draft the before/after JSX diff and show it to the user in the chat.
5. **Ask for confirmation before writing.** This command is interactive, unlike `/devpanl:init`.
6. On "go", apply a single targeted `Edit`. Add the auth import at the top of the file only if needed.
7. Re-read the file to confirm the final JSX is balanced.
8. Report what changed in one short block.

Escalations:

- **No mount found** → tell the user the widget isn't installed here; suggest adding it or stop.
- **Multiple mounts** → list them, ask which to update.
- **No detectable auth source** → write the target JSX with a `__SET_ME__` placeholder and tell the user to finish by hand.

Never commit. The user reviews the diff and commits themselves.
