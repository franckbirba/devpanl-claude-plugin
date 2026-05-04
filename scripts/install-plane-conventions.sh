#!/usr/bin/env bash
# install-plane-conventions.sh — install the `plane-conventions` skill, the
# PreToolUse reminder hook, and the CLAUDE.md anchor into the current project.
#
# Idempotent: re-running is safe — replaces resolved sections in place,
# leaves untouched files alone, never deletes user edits outside the
# auto-managed markers.
#
# Inputs (env > defaults):
#   PLUGIN_ROOT     plugin root (default: ${CLAUDE_PLUGIN_ROOT})
#   PROJECT_DIR    project root (default: ${CLAUDE_PROJECT_DIR:-$PWD})
#   PLANE_TOKEN    optional — if present, resolves Plane state/module/label
#                  IDs and the modules list from the API and injects them
#                  into the skill. Otherwise, placeholders are left and the
#                  user fills the blocks by hand.
#   PLANE_BASE_URL optional — defaults to https://plane.devpanl.dev
#
# Outputs into the project:
#   .claude/skills/plane-conventions/SKILL.md
#   .claude/hooks/plane-conventions-reminder.sh   (chmod +x)
#   .claude/settings.json                         (PreToolUse hook merged)
#   CLAUDE.md                                     (anchor section appended)

set -euo pipefail

err()  { printf "✗ %s\n" "$*" >&2; exit 1; }
info() { printf "▎ %s\n" "$*"; }
ok()   { printf "✓ %s\n" "$*"; }
warn() { printf "⚠ %s\n" "$*"; }

PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
PROJECT_DIR="${PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"
PLANE_BASE_URL="${PLANE_BASE_URL:-https://plane.devpanl.dev}"

[[ -n "$PLUGIN_ROOT" ]] || err "PLUGIN_ROOT or CLAUDE_PLUGIN_ROOT must be set"
[[ -d "$PROJECT_DIR" ]] || err "PROJECT_DIR not a directory: $PROJECT_DIR"
[[ -f "$PROJECT_DIR/.devpanlrc.json" ]] || err "$PROJECT_DIR is not devpanl-ready (missing .devpanlrc.json) — run /devpanl:init first"

command -v jq >/dev/null || err "jq not found — install jq first (brew install jq / apt install jq)"

SKILL_TEMPLATE="$PLUGIN_ROOT/skills/plane-conventions.md"
HOOK_TEMPLATE="$PLUGIN_ROOT/scripts/_templates/plane-conventions-reminder.sh"

[[ -f "$SKILL_TEMPLATE" ]] || err "skill template not found: $SKILL_TEMPLATE"
[[ -f "$HOOK_TEMPLATE"  ]] || err "hook template not found: $HOOK_TEMPLATE"

# --- read project metadata --------------------------------------------------

plane_project_id="$(jq -r '.plane.project_id // empty' "$PROJECT_DIR/.devpanlrc.json")"
plane_workspace="$(jq -r '.plane.workspace_slug // .plane.workspace // "devpanl"' "$PROJECT_DIR/.devpanlrc.json")"
github_repo="$(jq -r '.github.repo // empty' "$PROJECT_DIR/.devpanlrc.json")"

# Best-guess project display name: last segment of github.repo, else basename.
if [[ -n "$github_repo" ]]; then
  project_name="${github_repo##*/}"
else
  project_name="$(basename "$PROJECT_DIR")"
fi

info "project:       $project_name"
info "workspace:     $plane_workspace"
info "project_id:    ${plane_project_id:-__SET_ME__}"
info "github repo:   ${github_repo:-__SET_ME__}"

# --- 1. write SKILL.md from template ---------------------------------------

SKILL_DIR="$PROJECT_DIR/.claude/skills/plane-conventions"
mkdir -p "$SKILL_DIR"
SKILL_OUT="$SKILL_DIR/SKILL.md"

# sed escape: only matters for slashes in repo paths or workspace slugs.
sed_escape() { printf '%s' "$1" | sed 's/[\/&|]/\\&/g'; }

sed \
  -e "s|__PROJECT_NAME__|$(sed_escape "$project_name")|g" \
  -e "s|__PLANE_PROJECT_ID__|$(sed_escape "${plane_project_id:-__SET_ME__}")|g" \
  -e "s|__PLANE_WORKSPACE__|$(sed_escape "$plane_workspace")|g" \
  -e "s|__GITHUB_REPO__|$(sed_escape "${github_repo:-__SET_ME__}")|g" \
  "$SKILL_TEMPLATE" > "$SKILL_OUT"

ok "skill written to $SKILL_OUT"

# --- 2. resolve Plane IDs + modules list (optional, needs PLANE_TOKEN) -----

if [[ -n "${PLANE_TOKEN:-}" && -n "$plane_project_id" ]]; then
  info "resolving Plane states/modules/labels via API…"

  api() {
    local path="$1"
    curl -fsS -H "X-API-Key: $PLANE_TOKEN" \
      "$PLANE_BASE_URL/api/v1/workspaces/$plane_workspace/projects/$plane_project_id/$path/"
  }

  states_json="$(api states || true)"
  modules_json="$(api modules || true)"
  labels_json="$(api labels || true)"

  # IDs cheatsheet block
  ids_block="$(
    {
      printf 'project_id  = %s\n' "$plane_project_id"
      printf '%s\n' "$states_json"  | jq -r '.results[]? | "state.\(.name) = \(.id)"' 2>/dev/null || true
      printf '%s\n' "$modules_json" | jq -r '.results[]? | "module.\(.name) = \(.id)"' 2>/dev/null || true
      printf '%s\n' "$labels_json"  | jq -r '.results[]? | "label.\(.name) = \(.id)"' 2>/dev/null || true
    }
  )"

  # Modules table block (markdown)
  modules_table="$(
    printf '%s\n' "$modules_json" \
      | jq -r '.results[]? | "| `\(.name)` | \((.description // "_à compléter_") | gsub("\n"; " ")) |"' 2>/dev/null || true
  )"

  if [[ -z "$modules_table" ]]; then
    modules_table="| \`__SET_ME__\` | (no module returned by Plane — create one or check PLANE_TOKEN scope) |"
  fi

  modules_block="| Module name | Périmètre |
|-------------|-----------|
$modules_table"

  # Replace BEGIN_PLANE_IDS / END_PLANE_IDS block in place.
  awk -v ids="$ids_block" '
    BEGIN { skip=0 }
    /<!-- BEGIN_PLANE_IDS -->/ {
      print
      print ""
      print "```"
      print ids
      print "```"
      print ""
      skip=1
      next
    }
    /<!-- END_PLANE_IDS -->/ { skip=0; print; next }
    !skip { print }
  ' "$SKILL_OUT" > "$SKILL_OUT.tmp" && mv "$SKILL_OUT.tmp" "$SKILL_OUT"

  # Replace BEGIN_PLANE_MODULES / END_PLANE_MODULES block in place.
  awk -v modules="$modules_block" '
    BEGIN { skip=0 }
    /<!-- BEGIN_PLANE_MODULES -->/ {
      print
      print modules
      skip=1
      next
    }
    /<!-- END_PLANE_MODULES -->/ { skip=0; print; next }
    !skip { print }
  ' "$SKILL_OUT" > "$SKILL_OUT.tmp" && mv "$SKILL_OUT.tmp" "$SKILL_OUT"

  ok "Plane IDs + modules list injected"
else
  info "skipping Plane API resolution (PLANE_TOKEN not set or no project_id) — placeholders left in skill"
fi

# --- 3. install hook -------------------------------------------------------

HOOK_DIR="$PROJECT_DIR/.claude/hooks"
mkdir -p "$HOOK_DIR"
cp "$HOOK_TEMPLATE" "$HOOK_DIR/plane-conventions-reminder.sh"
chmod +x "$HOOK_DIR/plane-conventions-reminder.sh"
ok "hook written to $HOOK_DIR/plane-conventions-reminder.sh"

# --- 4. merge .claude/settings.json ----------------------------------------

SETTINGS="$PROJECT_DIR/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || printf '{}\n' > "$SETTINGS"

# Validate that the existing file parses; if not, abort rather than nuking.
jq -e . "$SETTINGS" >/dev/null 2>&1 || err "$SETTINGS does not parse as JSON — fix it or move it aside, then re-run."

MATCHER="mcp__plane__create_work_item|mcp__plane__update_work_item|mcp__plane__create_work_item_comment|mcp__plane__update_work_item_comment|mcp__plane__create_cycle|mcp__plane__update_cycle|mcp__plane__create_module|mcp__plane__update_module|mcp__plane__create_label|mcp__plane__update_label|mcp__plane__create_state|mcp__plane__update_state"

jq --arg matcher "$MATCHER" --arg cmd '${CLAUDE_PROJECT_DIR}/.claude/hooks/plane-conventions-reminder.sh' '
  .hooks            //= {} |
  .hooks.PreToolUse //= [] |
  if any(.hooks.PreToolUse[]?; .matcher == $matcher) then .
  else .hooks.PreToolUse += [{
    matcher: $matcher,
    hooks: [{ type: "command", command: $cmd }]
  }]
  end
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
ok "settings.json hook entry merged"

# --- 5. anchor in CLAUDE.md -----------------------------------------------

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
ANCHOR="## Plane conventions — MANDATORY before any Plane MCP call"

if [[ -f "$CLAUDE_MD" ]]; then
  if grep -qF "$ANCHOR" "$CLAUDE_MD"; then
    info "CLAUDE.md anchor already present — skip"
  else
    cat >> "$CLAUDE_MD" <<'EOF'

## Plane conventions — MANDATORY before any Plane MCP call

Before creating, updating, classifying, or reorganizing **any** Plane work item,
cycle, module, label, or comment in this project, you MUST invoke the
`plane-conventions` skill (`.claude/skills/plane-conventions/SKILL.md`). It is
the single source of truth for naming, taxonomy, description templates, and
lifecycle. A PreToolUse hook reminds agents on every `mcp__plane__create_*` /
`mcp__plane__update_*`. Don't bypass — fix the skill via PR if a rule is wrong.
EOF
    ok "CLAUDE.md anchor appended"
  fi
else
  warn "no CLAUDE.md found — skipped anchor (run /devpanl:init to create one, then re-run this)"
fi

# --- done ------------------------------------------------------------------

cat <<EOF

✓ plane-conventions installed in $PROJECT_DIR
   skill:    .claude/skills/plane-conventions/SKILL.md
   hook:     .claude/hooks/plane-conventions-reminder.sh
   settings: .claude/settings.json (PreToolUse hook merged)
   anchor:   CLAUDE.md (## Plane conventions section)

Next:
  1. Review the skill and edit §1.1 (modules autorisés) to match this project's
     stable module list. If you exported PLANE_TOKEN, that table is already
     populated from Plane; otherwise it has __SET_ME__.
  2. Commit the four files above.
  3. Run /devpanl:doctor to confirm the readiness check turns green.
EOF
