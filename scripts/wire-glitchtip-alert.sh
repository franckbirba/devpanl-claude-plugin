#!/usr/bin/env bash
# wire-glitchtip-alert.sh — find-or-create the `forward-to-devpanl` alert on a
# GlitchTip project so its events POST into the devpanel bridge.
#
# Idempotent: if an alert with the same name already exists for the project,
# only patches the URL/recipient when it drifts; otherwise no-op.
#
# Inputs (env > flags):
#   GLITCHTIP_API_TOKEN              required — bearer for glitchtip.devpanl.dev/api
#   GLITCHTIP_BRIDGE_HMAC_SECRET     required — querystring secret for the bridge
#   GLITCHTIP_BASE_URL               optional — defaults to https://glitchtip.devpanl.dev
#   GLITCHTIP_ORG                    optional — defaults to devpanl-studio
#   --team   <slug>                  required — GlitchTip team slug owning the project
#   --project <slug>                 required — GlitchTip project slug
#   --devpanl-project <uuid>         required — devpanl project id (bridge path segment)
#   --bridge-url <url>               optional — overrides the default internal URL
#   --alert-name <name>              optional — defaults to forward-to-devpanl
#
# The bridge URL **must** be the internal Docker URL by default:
#   http://devpanel-api:3030/api/webhooks/glitchtip/<devpanl-project-id>?secret=<hmac>
# Cloudflare WAF rule 1010 blocks the worker on the public hostname (DEVPA-168).
#
# Exit 0 on success (created or already-good). Non-zero on missing inputs or
# API errors.

set -euo pipefail

err() { printf "✗ %s\n" "$*" >&2; exit 1; }
info() { printf "▎ %s\n" "$*"; }
ok() { printf "✓ %s\n" "$*"; }
warn() { printf "⚠ %s\n" "$*"; }

GLITCHTIP_BASE_URL="${GLITCHTIP_BASE_URL:-https://glitchtip.devpanl.dev}"
GLITCHTIP_ORG="${GLITCHTIP_ORG:-devpanl-studio}"
ALERT_NAME="forward-to-devpanl"
TEAM=""
PROJECT=""
DEVPANL_PROJECT_ID=""
BRIDGE_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team) TEAM="$2"; shift 2;;
    --project) PROJECT="$2"; shift 2;;
    --devpanl-project) DEVPANL_PROJECT_ID="$2"; shift 2;;
    --bridge-url) BRIDGE_URL="$2"; shift 2;;
    --alert-name) ALERT_NAME="$2"; shift 2;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) err "unknown arg: $1";;
  esac
done

[[ -n "${GLITCHTIP_API_TOKEN:-}" ]] || err "GLITCHTIP_API_TOKEN not set"
[[ -n "${GLITCHTIP_BRIDGE_HMAC_SECRET:-}" ]] || err "GLITCHTIP_BRIDGE_HMAC_SECRET not set"
[[ -n "$TEAM" ]] || err "--team <slug> required"
[[ -n "$PROJECT" ]] || err "--project <slug> required"
[[ -n "$DEVPANL_PROJECT_ID" ]] || err "--devpanl-project <uuid> required"

command -v curl >/dev/null || err "curl not found"
command -v jq >/dev/null || err "jq not found"

if [[ -z "$BRIDGE_URL" ]]; then
  BRIDGE_URL="http://devpanel-api:3030/api/webhooks/glitchtip/${DEVPANL_PROJECT_ID}?secret=${GLITCHTIP_BRIDGE_HMAC_SECRET}"
fi

API="${GLITCHTIP_BASE_URL%/}/api/0/projects/${GLITCHTIP_ORG}/${PROJECT}/alerts/"

info "GlitchTip:    ${GLITCHTIP_BASE_URL}"
info "Org / team:   ${GLITCHTIP_ORG} / ${TEAM}"
info "Project:      ${PROJECT}"
info "Bridge URL:   ${BRIDGE_URL%%\?*}?secret=***"

http() {
  local method="$1" url="$2" body="${3:-}"
  local args=(-sS -o /tmp/wire-glitchtip-body.$$ -w '%{http_code}'
    -H "Authorization: Bearer ${GLITCHTIP_API_TOKEN}"
    -H "Content-Type: application/json"
    -X "$method" "$url")
  [[ -n "$body" ]] && args+=(--data-raw "$body")
  local code
  code="$(curl "${args[@]}")" || err "curl failed against $url"
  cat /tmp/wire-glitchtip-body.$$
  rm -f /tmp/wire-glitchtip-body.$$
  printf '\n%s' "$code"
}

# --- list existing alerts ---------------------------------------------------

LIST_RAW="$(http GET "$API")"
LIST_CODE="${LIST_RAW##*$'\n'}"
LIST_BODY="${LIST_RAW%$'\n'*}"

case "$LIST_CODE" in
  200) ;;
  401|403) err "GlitchTip rejected GLITCHTIP_API_TOKEN ($LIST_CODE). Token needs project:admin on $GLITCHTIP_ORG/$PROJECT.";;
  404) err "GlitchTip project not found: ${GLITCHTIP_ORG}/${PROJECT} (404). Check slug.";;
  *)   err "GlitchTip GET $API → $LIST_CODE: $LIST_BODY";;
esac

EXISTING_ID="$(printf '%s' "$LIST_BODY" | jq -r --arg n "$ALERT_NAME" \
  '.[]? | select(.name==$n) | .pk // .id' | head -1)"

PAYLOAD="$(jq -nc \
  --arg name "$ALERT_NAME" \
  --arg url "$BRIDGE_URL" \
  '{
     name: $name,
     timespan_minutes: 1,
     quantity: 1,
     alertRecipients: [{recipientType: "webhook", url: $url}]
   }')"

if [[ -z "$EXISTING_ID" ]]; then
  CREATE_RAW="$(http POST "$API" "$PAYLOAD")"
  CREATE_CODE="${CREATE_RAW##*$'\n'}"
  CREATE_BODY="${CREATE_RAW%$'\n'*}"
  case "$CREATE_CODE" in
    200|201) ok "alert created: $ALERT_NAME";;
    *) err "GlitchTip POST $API → $CREATE_CODE: $CREATE_BODY";;
  esac
  exit 0
fi

# --- compare current recipient URL ------------------------------------------

CURRENT_URL="$(printf '%s' "$LIST_BODY" \
  | jq -r --arg n "$ALERT_NAME" \
      '.[]? | select(.name==$n) | .alertRecipients[0]?.url // ""' \
  | head -1)"

if [[ "$CURRENT_URL" == "$BRIDGE_URL" ]]; then
  ok "alert already wired (matching URL): $ALERT_NAME (id=$EXISTING_ID)"
  exit 0
fi

PUT_URL="${API}${EXISTING_ID}/"
PATCH_RAW="$(http PUT "$PUT_URL" "$PAYLOAD")"
PATCH_CODE="${PATCH_RAW##*$'\n'}"
PATCH_BODY="${PATCH_RAW%$'\n'*}"
case "$PATCH_CODE" in
  200|201|204) ok "alert updated (URL drift fixed): $ALERT_NAME (id=$EXISTING_ID)";;
  *) err "GlitchTip PUT $PUT_URL → $PATCH_CODE: $PATCH_BODY";;
esac
