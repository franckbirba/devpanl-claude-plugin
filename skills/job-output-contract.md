---
name: job-output-contract
description: The exact JSON shape every claude -p agent run must emit as its final output. Worker's parseResult depends on this; without it the workflow engine cannot route the run.
---

# Job output contract

Every agent invoked by the DevPanel worker MUST end its `claude -p` run with a single fenced ```json block as the last thing it writes. Anything after is ignored by the parser; anything missing is fatal.

## Shape

```json
{
  "status": "done | failed | blocked",
  "summary": "One sentence (<=240 chars), Telegram-friendly, no newlines.",
  "artifacts": {
    "files_created": [],
    "files_modified": [],
    "commits": ["<sha-or-message>"],
    "branch": "feat/...",
    "tests_passed": true,
    "pr_url": null
  },
  "issues_found": [],
  "blockers": [],
  "handoff": {
    "next_agent": null,
    "reason": null
  },
  "memory_writes_count": 0
}
```

## Field rules

### status (required)

- `done` — happy path. Workflow engine advances per the YAML's `on.done`.
- `failed` — agent did its job but the answer is "no, this branch is not shippable" (e.g. reviewer rejection, qa regression). Engine fires the `on.failed` branch (often replan).
- `blocked` — agent cannot make progress without external input (missing description, broken infra, plane lookup 404). Engine fires `on.blocked`, usually PM replan.

Anything else is treated as `failed` and logs a parser warning.

### summary (required)

One line, ≤240 chars, ASCII-safe. The worker truncates at 240 anyway and Telegram poisons on long markdown. Don't paste full commit messages here.

### artifacts (recommended)

Empty arrays are fine. `branch` is what publisher pushes — set it to your real branch name. `pr_url` only set when YOU created the PR (publisher usually does this).

### issues_found / blockers

Used by reviewer (`issues_found`) and any role returning `blocked` (`blockers`). PM replan reads these to decide what to do.

### handoff.next_agent

Optional retreat hint. Engine respects it only if the current step's YAML has `retreat_allowed: [<agent>]`. Use sparingly — it bypasses the normal forward chain.

### memory_writes_count

If you used the `memory_write` MCP tool, set this to how many times you called it. The worker verifies this against the actual count in `agent_memory`. A mismatch fails the job — guards against agents claiming work they didn't do.

## Common mistakes

- Trailing prose after the JSON block. → Parser regex finds the last fenced json, but anything that pollutes the block (comments, trailing comma) drops the whole thing. Use `JSON.stringify(obj, null, 2)` mental model.
- Putting markdown in `summary`. → Backticks, asterisks, newlines crash downstream telegram bun. Plain text only.
- Forgetting `tests_passed`. → QA's downstream gate uses it; missing = treated as false.
- Returning multiple JSON blocks. → Only the LAST one is parsed.

## Minimal valid output

```json
{"status":"done","summary":"All good"}
```

The parser fills the rest with sensible defaults. Don't over-engineer if the run has nothing to report.
