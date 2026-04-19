---
description: "Dispatch the work-item workflow on a Plane work item — usage: /devpanl:dispatch <plane-uuid-or-DEVPA-NN>"
argument-hint: <plane-uuid-or-sequence-id>
---

Dispatch a DevPanel work-item workflow on the Plane work item passed as `$ARGUMENTS`.

Steps:

1. Read `.devpanlrc.json` for `plane.workspace_slug` and `plane.project_id`. If `project_id` is `__SET_ME__` or missing, refuse and tell the user to run `/devpanl:init` first.

2. Resolve the work item id:
   - If `$ARGUMENTS` matches `^[A-Z]+-\d+$` (sequence id like `DEVPA-34`), call the Plane MCP `list_work_items` (or REST `GET /api/v1/workspaces/<slug>/projects/<pid>/issues/?per_page=100`) and find the issue with that `sequence_id`. Use its UUID.
   - Otherwise treat `$ARGUMENTS` as a UUID directly.

3. Verify devpanel MCP is available. If not, tell the user `/devpanl:doctor` will diagnose; bail.

4. Call the devpanel MCP tool `devpanel_workflow_dispatch` (or `enqueue_job` with `workflow: "work-item"`) with:
   - `work_item_id`: resolved UUID
   - `module_id`, `cycle_id`: from the Plane issue if present, otherwise null

5. Report:
   - `instance_id` and `job_id` returned by the MCP
   - The dashboard URL: `https://devpanl.dev/dashboard/queues`
   - Estimated time to first activity: ~5s (worker pickup) + builder run

Refuse if the readiness check is red — running jobs against an unready project wastes claude tokens and pollutes Plane state.
