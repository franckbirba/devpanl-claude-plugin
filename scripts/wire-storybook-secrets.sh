#!/usr/bin/env bash
# wire-storybook-secrets.sh — provision GitHub Actions secrets for the
# ui.devpanl.dev sync workflow on the current repo.
#
# What it does (idempotent):
#   1. Detects the project slug (matches /devpanl:add-storybook logic).
#   2. Generates a per-project ed25519 keypair under
#      ~/.devpanl/keys/storybook_sync_<slug> (skips if it already exists).
#   3. SSHes to $VPS_HOST and appends the public key to the remote
#      authorized_keys (skips if the key is already there).
#   4. Writes STORYBOOK_SYNC_SSH_KEY and VPS_HOST as repo secrets via gh.
#
# Requires: bash, ssh, ssh-keygen, gh (logged in), git.
#
# Usage (from inside the target project repo):
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/franckbirba/devpanl-claude-plugin/main/scripts/wire-storybook-secrets.sh)
#
# Override the VPS host once and it's cached for next runs:
#
#   DEVPANL_VPS_HOST=deploy@ui.devpanl.dev bash <(curl ...)
#
# The cache lives at ~/.devpanl/vps-host. Delete it to be re-prompted.

set -euo pipefail

err() { printf "✗ %s\n" "$*" >&2; exit 1; }
info() { printf "▎ %s\n" "$*"; }
ok() { printf "✓ %s\n" "$*"; }
warn() { printf "⚠ %s\n" "$*"; }

# --- preflight --------------------------------------------------------------

command -v gh >/dev/null  || err "gh CLI not found. Install: https://cli.github.com/"
command -v ssh >/dev/null || err "ssh not found."
command -v ssh-keygen >/dev/null || err "ssh-keygen not found."
command -v git >/dev/null || err "git not found."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || err "Not inside a git repository. cd into the target project first."

gh auth status >/dev/null 2>&1 \
  || err "gh is not authenticated. Run: gh auth login"

# --- slug -------------------------------------------------------------------

resolve_slug() {
  local slug=""

  if [[ -f .devpanlrc.json ]]; then
    slug="$(python3 -c '
import json, sys
try:
    d = json.load(open(".devpanlrc.json"))
    repo = d.get("github", {}).get("repo", "")
    if "/" in repo:
        print(repo.rsplit("/", 1)[1])
except Exception:
    pass
' 2>/dev/null || true)"
  fi

  if [[ -z "$slug" ]]; then
    local origin
    origin="$(git remote get-url origin 2>/dev/null || true)"
    if [[ -n "$origin" ]]; then
      slug="${origin##*/}"
      slug="${slug%.git}"
    fi
  fi

  if [[ -z "$slug" ]]; then
    slug="$(basename "$PWD")"
  fi

  slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | tr -s '-' | sed 's/^-//; s/-$//')"
  slug="${slug:0:30}"
  [[ -n "$slug" ]] || err "Could not resolve a project slug."
  printf '%s' "$slug"
}

SLUG="$(resolve_slug)"
ok "slug: $SLUG"

# --- vps host ---------------------------------------------------------------

CACHE_DIR="$HOME/.devpanl"
HOST_CACHE="$CACHE_DIR/vps-host"
mkdir -p "$CACHE_DIR"

# Precedence: cache (per-machine, set once) > $DEVPANL_VPS_HOST (override) > prompt.
VPS_HOST=""
CACHED_FROM=""
if [[ -f "$HOST_CACHE" ]]; then
  VPS_HOST="$(<"$HOST_CACHE")"
  CACHED_FROM="cached"
fi
if [[ -z "$VPS_HOST" && -n "${DEVPANL_VPS_HOST:-}" ]]; then
  VPS_HOST="$DEVPANL_VPS_HOST"
  CACHED_FROM="env"
fi
if [[ -z "$VPS_HOST" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "VPS host (e.g. deploy@ui.devpanl.dev): " VPS_HOST
    CACHED_FROM="prompt"
  else
    err "VPS host not set. Set it once with: echo 'deploy@ui.devpanl.dev' > $HOST_CACHE"
  fi
fi
[[ -n "$VPS_HOST" ]] || err "VPS host is empty."
printf '%s' "$VPS_HOST" > "$HOST_CACHE"
case "$CACHED_FROM" in
  cached) ok "vps host: $VPS_HOST (from $HOST_CACHE)" ;;
  env)    ok "vps host: $VPS_HOST (from \$DEVPANL_VPS_HOST — cached for next runs)" ;;
  prompt) ok "vps host: $VPS_HOST (cached at $HOST_CACHE — future projects won't ask)" ;;
esac

# --- keypair ----------------------------------------------------------------

KEY_DIR="$CACHE_DIR/keys"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
KEY_PATH="$KEY_DIR/storybook_sync_$SLUG"

if [[ -f "$KEY_PATH" ]]; then
  ok "key exists: $KEY_PATH (reusing)"
else
  ssh-keygen -t ed25519 -C "storybook-sync@$SLUG" -f "$KEY_PATH" -N "" >/dev/null
  chmod 600 "$KEY_PATH"
  ok "key generated: $KEY_PATH"
fi

PUBKEY="$(<"$KEY_PATH.pub")"

# --- push pubkey to vps -----------------------------------------------------

REMOTE_LINE="$PUBKEY"
# Append only if not already there. The remote check is one round-trip.
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$VPS_HOST" "
  set -e
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  if grep -qxF '$REMOTE_LINE' ~/.ssh/authorized_keys; then
    echo present
  else
    echo '$REMOTE_LINE' >> ~/.ssh/authorized_keys
    echo appended
  fi
" 2>/tmp/wire-storybook-ssh.err; then
  RES="$(ssh -o BatchMode=yes "$VPS_HOST" "grep -qxF '$REMOTE_LINE' ~/.ssh/authorized_keys && echo present || echo missing" 2>/dev/null || echo unknown)"
  case "$RES" in
    present) ok "pubkey installed on $VPS_HOST" ;;
    *) warn "pubkey upload uncertain — verify ~/.ssh/authorized_keys on $VPS_HOST" ;;
  esac
else
  cat /tmp/wire-storybook-ssh.err >&2 || true
  err "ssh to $VPS_HOST failed. Make sure you can: ssh $VPS_HOST"
fi

# --- github secrets ---------------------------------------------------------

# gh secret set reads the secret value from stdin when --body is omitted.
gh secret set STORYBOOK_SYNC_SSH_KEY < "$KEY_PATH" >/dev/null
ok "set STORYBOOK_SYNC_SSH_KEY"

gh secret set VPS_HOST --body "$VPS_HOST" >/dev/null
ok "set VPS_HOST"

# --- done -------------------------------------------------------------------

cat <<EOF

✓ storybook secrets wired for $SLUG
   key:        $KEY_PATH
   vps host:   $VPS_HOST
   gh secrets: STORYBOOK_SYNC_SSH_KEY, VPS_HOST

Next: push to main. The Sync stories workflow will run and publish to
https://ui.devpanl.dev/$SLUG/.
EOF
