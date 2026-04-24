# devpanl

Wire any project into the **DevPanel** autonomous agent team.

Install this plugin in a project (zeno, edms, …) and the team can dispatch builder → reviewer → qa → publisher jobs against it with a high success rate. The plugin reads the codebase, generates calibrated agent SOULs, and links the project to the central DevPanel control plane.

## Install

Inside any Claude Code session:

```
/plugin marketplace add franckbirba/devpanl-claude-plugin
/plugin install devpanl@devpanl-claude-plugin
/reload-plugins
```

Then, in the project root:

```
/devpanl:init
```

That's it. Silent — no questions. Reads your `package.json` / `Cargo.toml` / `pyproject.toml` / `Makefile` / CI workflows, infers build/test/lint commands, generates a calibrated SOUL for every agent role, and writes the integration section into `CLAUDE.md`.

After init, edit any unresolved values flagged in the report (typically just `plane.project_id` if Plane wasn't already wired) and commit.

## What gets generated

| Path                            | Purpose                                                                |
| ------------------------------- | ---------------------------------------------------------------------- |
| `.devpanlrc.json`               | Plane project id, GitHub repo, branch convention, forbidden paths      |
| `CLAUDE.md` (integration section) | Build/test/lint commands the agents copy-paste                       |
| `.mcp.json`                     | DevPanel MCP server entry (preserves any existing entries)             |
| `.agents/builder/SOUL.md`       | Builder agent — minimal-impact code edits, branch + push convention    |
| `.agents/reviewer/SOUL.md`      | Reviewer — diff review, tests, lint, retreat-to-builder allowed        |
| `.agents/qa/SOUL.md`            | QA — full test suite + build, regression detection                     |
| `.agents/architect/SOUL.md`     | Architect — ADR authoring                                              |
| `.agents/designer/SOUL.md`      | Designer — Penpot frames + design tokens                               |
| `.agents/pm/SOUL.md`            | PM — replan blocked workflows, daily/weekly sync                       |
| `.agents/deploy/SOUL.md`        | Deploy — production deploy on demand or schedule                       |

## Commands

- `/devpanl:init` — make this project devpanl-ready in one silent pass.
- `/devpanl:doctor` — verify readiness without modifying files. Reports ✓/⚠/✗ per check.
- `/devpanl:dispatch <DEVPA-NN | uuid>` — kick off a workflow on a Plane work item.
- `/devpanl:pull-backlog [--enqueue]` — preview (or trigger) the agent-ready queue.
- `/devpanl:update-widget` — wire the `@devpanel/react` widget `user` prop to the host app's auth so captures carry reporter identity. Interactive: shows a diff and asks before writing.

## How agent dispatch actually works

1. You label a Plane work item `agent-ready`.
2. Within 15 min, the DevPanel worker (running on the agents host) picks it up via the backlog puller.
3. The worker spawns `claude -p` in *this project's directory*. That's why the SOULs live here, in your repo: `claude -p` reads them on startup and behaves like a calibrated team member.
4. Builder writes code on a `feat/<short-id>-<slug>` branch, pushes, hands off to reviewer.
5. Reviewer runs your project's tests and lint; QA runs the full suite + build; publisher opens a PR and moves Plane to Done.
6. You get a Telegram ping with the PR URL.

If any step fails, PM (replan workflow) is invoked to decide how to recover. After 3 revisions without success, the workflow is marked `exhausted` and waits for human input.

## Per-project Plane mapping

Each project owns its `plane.project_id` in `.devpanlrc.json`. The DevPanel worker reads this when dispatching, so the same agent team can serve N projects without env-var collisions.

## Compatibility

The plugin generates commands and SOULs from observed project structure. Supported stacks include: Node (npm/pnpm/yarn), Rust, Python (pyproject/poetry/hatch), Go, Java (Maven/Gradle), PHP (composer), Ruby (bundler), .NET. Other stacks: the analyzer drops what it can't detect rather than guessing — `/devpanl:doctor` will flag the gaps.

## License

MIT.
