---
description: List Plane Todos labelled agent-ready in this project; optionally enqueue them.
argument-hint: "[--enqueue]"
---

List Plane work items in the current project's backlog that are eligible for autonomous pickup, then optionally enqueue them.

Steps:

1. Read `.devpanlrc.json` for `plane.workspace_slug` and `plane.project_id`. If missing, refuse and point at `/devpanl:init`.

2. Query Plane (REST or `plane` MCP):
   - State group: `unstarted` (i.e. "Todo")
   - Label: `agent-ready` (resolve to label id from `/labels/`)

3. For each match, print one line:
   `DEVPA-<seq>  <title>  (priority: <p>, cycle: <name>)`

4. If `$ARGUMENTS` includes `--enqueue`:
   - For each item, call devpanel MCP `devpanel_workflow_dispatch` with `workflow: "work-item"` and the work item UUID.
   - Print the resulting `job_id` per item.
   - Skip silently when `enqueueWorkflowStart` returns `already_running` (workflow_instances dedup).
   - Report totals: `dispatched=N already=M failed=K`.

5. Without `--enqueue`, the worker's continuous backlog-puller (`BACKLOG_PULL_ENABLED=true`) picks the same set up automatically every 15 min — this command is a manual override / preview.

Useful when you want to see the queue before bed, or to push a burst of work without waiting for the next 15-min tick.
