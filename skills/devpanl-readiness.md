---
name: devpanl-readiness
description: The contract a project must satisfy to be safely dispatched to by the DevPanel agent team. Use this when running /devpanl:init or /devpanl:doctor — it defines what to look for, what to generate, and how to verify.
---

# DevPanel readiness contract

A repository is **devpanl-ready** when an ephemeral `claude -p` spawned by the worker can land in its directory and successfully execute a builder/reviewer/qa/architect/designer/pm/deploy job without further human guidance.

This skill defines the readiness checklist used by the `/devpanl:init` (generate) and `/devpanl:doctor` (verify) commands.

## What every devpanl-ready repo must have

### 1. `CLAUDE.md` with a "DevPanel integration" section

Required keys (use this exact subheading so doctor can find it):

```markdown
## DevPanel integration

- Plane project id: `<uuid>`
- GitHub repo: `<owner>/<name>`
- Default branch: `<main|master|...>`
- Branch convention: `feat/<plane-short-id>-<slug>`
- Build: `<exact command>`
- Test: `<exact command>`
- Lint: `<exact command>`  *(omit if none)*
- Typecheck: `<exact command>`  *(omit if none)*
- Forbidden paths: `<comma-separated>` *(e.g. migrations/, secrets/, .env*)*
```

### 2. `.devpanlrc.json` with `plane.project_id`

```json
{
  "plane": {
    "project_id": "<uuid>",
    "workspace_slug": "devpanl"
  },
  "github": {
    "repo": "owner/name",
    "default_branch": "main"
  },
  "agents": {
    "branch_prefix": "feat/",
    "forbidden_paths": ["migrations/", ".env*"]
  }
}
```

The worker reads this file before dispatching jobs to the project, so `plane.project_id` is what links Plane work items back to the codebase.

### 3. `.agents/<role>/SOUL.md` for every role the team uses

Generated, project-specific. The full set is: **builder, reviewer, qa, architect, designer, pm, deploy**.

Each SOUL must be calibrated to the project — generic placeholders ("run your tests") are forbidden. Every command must be a copy-pasteable shell line that works in this repo's checkout.

See `soul-authoring` skill for templates and per-role rules.

### 4. `.mcp.json` with at least the devpanel MCP entry

```json
{
  "mcpServers": {
    "devpanel": {
      "type": "http",
      "url": "https://devpanl.dev/mcp",
      "headers": { "X-API-Key": "${DEVPANEL_API_KEY}" }
    }
  }
}
```

If the project also wants direct Plane / GitHub access, those can be added but aren't required — the worker enriches `work_item` from Plane REST before spawning, and the GitHub token is on the agent host.

### 5. A job output contract

Every agent run must terminate with a JSON object as the last fenced code block. See `job-output-contract` skill. Without this, `parseResult` in the worker can't extract `status`, `summary`, `artifacts`, and the workflow engine treats the job as failed.

## How the analyzer detects the project

Run these in order, stop at the first match:

| File / Marker            | Stack                  | Build           | Test                        | Lint                      |
| ------------------------ | ---------------------- | --------------- | --------------------------- | ------------------------- |
| `package.json`           | Node                   | `npm run build` *(if defined; else "no-op")* | `npm test` *(or scripts.test)* | `npm run lint` *(if defined)* |
| `pnpm-lock.yaml` present | swap `npm` → `pnpm`    |                 |                             |                           |
| `yarn.lock` present      | swap `npm` → `yarn`    |                 |                             |                           |
| `Cargo.toml`             | Rust                   | `cargo build --release` | `cargo test`        | `cargo clippy -- -D warnings` |
| `pyproject.toml`         | Python                 | `python -m build` *(if poetry/hatch)* | `pytest`     | `ruff check` *(or flake8)* |
| `go.mod`                 | Go                     | `go build ./...` | `go test ./...`            | `golangci-lint run` *(if config)* |
| `pom.xml`                | Java/Maven             | `mvn -B package` | `mvn -B test`              | `mvn -B verify`           |
| `build.gradle*`          | Java/Kotlin/Gradle     | `./gradlew build` | `./gradlew test`          | `./gradlew check`         |
| `composer.json`          | PHP                    | `composer install` | `composer test`          | —                         |
| `Gemfile`                | Ruby                   | `bundle install` | `bundle exec rspec` *(or rake test)* | `rubocop`         |
| `.csproj` / `.sln`       | .NET                   | `dotnet build`   | `dotnet test`              | —                         |

Check `Makefile` for `build`, `test`, `lint` targets and prefer those if present (they're project-specific shortcuts).

Check `package.json#scripts` for richer commands (`test:ci`, `lint:fix`, `typecheck`, `e2e`) — extract them faithfully into the SOULs.

Check `.github/workflows/*.yml` for `run:` steps — that's the ground truth for CI; mirror those commands into `qa` and `reviewer` SOULs so agents reproduce CI locally before landing.

## Forbidden-paths heuristics

Auto-detect patterns the builder must not modify without explicit task scope:

- `migrations/`, `db/migrate/`, `prisma/migrations/` — schema drift risk
- `.env*` — secret leak
- `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock` — only modify alongside dep changes
- `dist/`, `build/`, `out/`, `target/` — generated artefacts
- `LICENSE`, `CODE_OF_CONDUCT.md` — non-code, change deliberately
- `infra/`, `terraform/`, `k8s/`, `helm/` — infra changes need special handling

Add a path to `forbidden_paths` whenever the heuristic fires.

## Post-generation verification (`/devpanl:doctor` mode)

For each SOUL, run a smoke check:

1. Does the build command actually exist? (`which`, `npm run -l`, `cargo --list`, etc.)
2. Does the test command exit cleanly on a clean tree? (Run it; a failure is OK if the tests fail, but "command not found" is fatal.)
3. Does `.mcp.json` parse + does `${DEVPANEL_API_KEY}` resolve in the shell env?
4. Does `git remote get-url origin` match `.devpanlrc.json#github.repo`?
5. Is `plane.project_id` resolvable? (Try `curl -s -H "X-API-Key: $PLANE_API_KEY" "https://plane.devpanl.dev/api/v1/workspaces/devpanl/projects/<id>/" | jq .name` if PLANE_API_KEY is in env.)

Doctor reports per-check status:

- ✓ green: ready
- ⚠ yellow: works but suboptimal (e.g. forbidden_paths missing some heuristic)
- ✗ red: blocking (e.g. test command missing) — refuse to dispatch

## Check: Storybook authoring is wired

A project is storybook-ready when:

1. It has a `stories/` folder at the repo root (even if only `.keep` for
   now — signals intent and prevents the sync workflow from failing).
2. It has `.github/workflows/sync-stories.yml` invoking the reusable
   workflow from dev-panel with a valid `project-slug`.
3. The repo secrets `STORYBOOK_SYNC_SSH_KEY` and `VPS_HOST` are set.

If any of those are missing, flag it. Fix path: re-run `/devpanl:init`,
which now scaffolds the folder and caller workflow.
