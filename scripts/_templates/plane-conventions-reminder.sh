#!/usr/bin/env bash
# PreToolUse hook for Plane MCP write operations.
# Reminds the agent to load the `plane-conventions` skill before
# creating/updating work items, cycles, modules, labels, or comments.
#
# Exits 0 with stdout content -> Claude Code injects the message as
# additional context in the next turn (non-blocking).

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

case "$TOOL_NAME" in
  mcp__plane__create_work_item|\
  mcp__plane__update_work_item|\
  mcp__plane__create_work_item_comment|\
  mcp__plane__update_work_item_comment|\
  mcp__plane__create_cycle|\
  mcp__plane__update_cycle|\
  mcp__plane__create_module|\
  mcp__plane__update_module|\
  mcp__plane__create_label|\
  mcp__plane__update_label|\
  mcp__plane__create_state|\
  mcp__plane__update_state)
    cat <<'MSG'
[plane-conventions reminder]

You are about to write to Plane. Before proceeding, ensure you have
applied the rules from `.claude/skills/plane-conventions/SKILL.md`:

  • Title format:   [TAG] verbe + objet + — précision   (FR, 60–90 chars)
  • Allowed tags:   FEAT, BUG, ARCHI, REFACTO, INFRA, DOC, QA, DEMO, SPIKE, CHORE
  • Module:         exactly 1 from the closed list defined in §1.1 of
                    the skill (auto-resolved from this project's Plane
                    workspace at install time).
  • Labels:         1 type (feature|bug|architecture|qa) + 0–2 stack
                    (backend|fullstack|devops) + 0–1 lifecycle
                    (claude-ready|production|dev). Max 4. Don't recreate
                    legacy module-shaped labels (the module field
                    already carries that info).
  • Priority:       NEVER `none` at creation. Pick urgent|high|medium|low.
  • Description:    must contain Contexte / Travail à faire / Critères
                    d'acceptation / Fichiers à toucher / Dépendances.
                    Min ~200 chars. Empty descriptions are forbidden.
  • Cycle name:     <Sprint|MEP|Demo|Hotfix|Phase> <Wxx|YYYY-MM-DD> — <thème>
  • State on create: leave at Backlog unless you start immediately.

If unsure about IDs (modules, states, labels), the cheat sheet is in
section 8 of the skill. If a rule blocks you, fix the skill via PR — do
not bypass. Invoke the skill via the Skill tool now if you haven't.
MSG
    ;;
  *)
    : # silent for unrelated tools
    ;;
esac

exit 0
