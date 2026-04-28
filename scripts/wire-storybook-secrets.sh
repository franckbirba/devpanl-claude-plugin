#!/usr/bin/env bash
# wire-storybook-secrets.sh — provision GitHub Actions secrets for the
# ui.devpanl.dev sync workflow on the current repo.
#
# What it does (idempotent):
#   1. Detects the project slug (matches /devpanl:add-storybook logic).
#   2. Generates a per-project ed25519 keypair under
#      ~/.devpanl/keys/storybook_sync_<slug> (skips if it already exists).
#   3. Installs ~/bin/storybook-sync-rsync on the VPS (skips if hash matches).
#      This is a forced-command wrapper that allows ONLY the operations the
#      reusable workflow performs, scoped to <slug>: nothing else.
#   4. Appends (or replaces) the public key in the VPS authorized_keys with
#      a command="/home/deploy/bin/storybook-sync-rsync <slug>" prefix and
#      the usual no-pty/no-port-forwarding restrictions.
#   5. Writes STORYBOOK_SYNC_SSH_KEY and VPS_HOST as repo secrets via gh.
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

# --- install forced-command wrapper on vps (idempotent) ---------------------

# Resolves $SCRIPT_DIR/vps/storybook-sync-rsync. Falls back to a curl from
# main when invoked via bash <(curl …) (no on-disk SCRIPT_DIR sibling).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
WRAPPER_LOCAL="$SCRIPT_DIR/vps/storybook-sync-rsync"
if [[ ! -f "$WRAPPER_LOCAL" ]]; then
  WRAPPER_LOCAL="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/franckbirba/devpanl-claude-plugin/main/scripts/vps/storybook-sync-rsync \
    -o "$WRAPPER_LOCAL" \
    || err "could not fetch storybook-sync-rsync wrapper"
fi
chmod +x "$WRAPPER_LOCAL"

# Hash the local copy so we can detect drift on the VPS and refresh.
LOCAL_SHA="$(shasum -a 256 "$WRAPPER_LOCAL" | awk '{print $1}')"

REMOTE_SHA="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$VPS_HOST" \
  'sha256sum ~/bin/storybook-sync-rsync 2>/dev/null | awk "{print \$1}"' 2>/dev/null || true)"

if [[ "$REMOTE_SHA" == "$LOCAL_SHA" ]]; then
  ok "wrapper present on $VPS_HOST (sha matches)"
else
  scp -o BatchMode=yes "$WRAPPER_LOCAL" "$VPS_HOST:storybook-sync-rsync.tmp" >/dev/null \
    || err "scp wrapper to $VPS_HOST failed"
  ssh -o BatchMode=yes "$VPS_HOST" '
    set -e
    mkdir -p ~/bin
    mv ~/storybook-sync-rsync.tmp ~/bin/storybook-sync-rsync
    chmod 755 ~/bin/storybook-sync-rsync
  ' || err "installing wrapper on $VPS_HOST failed"
  ok "wrapper installed: $VPS_HOST:~/bin/storybook-sync-rsync"
fi

# --- push (locked-down) pubkey to vps ---------------------------------------

PREFIX="command=\"/home/deploy/bin/storybook-sync-rsync $SLUG\",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-user-rc"
LOCKED_LINE="$PREFIX $PUBKEY"

# Use a fingerprint from the key body to find any prior unlocked or differently-prefixed entry
# matching this same key, so we can atomically replace it with the locked-down version.
KEY_BODY="$(awk '{print $2}' "$KEY_PATH.pub")"

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$VPS_HOST" "
  set -e
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
  TMP=\$(mktemp)
  grep -vF '$KEY_BODY' ~/.ssh/authorized_keys > \"\$TMP\" || true
  echo '$LOCKED_LINE' >> \"\$TMP\"
  mv \"\$TMP\" ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
" 2>/tmp/wire-storybook-ssh.err; then
  ok "pubkey installed on $VPS_HOST (locked to slug=$SLUG, rsync-only)"
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
