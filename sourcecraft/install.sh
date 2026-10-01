#!/bin/bash
# Install SourceCraft models for opencode:
# src CLI -> local ipc proxy (systemd user service) -> provider config.
# Provider config itself (.config/opencode/opencode.jsonc) is stowed by the repo.
# Safe to re-run; on a machine without src it downloads the official installer.

set -e

DIR="$(dirname "$(readlink -f "$0")")"

# shellcheck disable=SC1091
source "$DIR/../shell/prompt_utils.sh"

PORT=8787
SRC_FALLBACK="$HOME/sourcecraft/bin/src"
KEY_DIR="$HOME/.config/sourcecraft-ipc"
KEY_FILE="$KEY_DIR/key"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/sourcecraft-ipc.service"
INSTALLER_URL="https://s3.yandexcloud.net/sourcecraft-cli/install.sh"

find_src() {
  if [ -x "$SRC_FALLBACK" ]; then
    echo "$SRC_FALLBACK"
  elif command -v src >/dev/null 2>&1; then
    command -v src
  else
    return 1
  fi
}

generate_key() {
  mkdir -p "$KEY_DIR"
  chmod 700 "$KEY_DIR"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24 >"$KEY_FILE"
  else
    od -An -N24 -tx1 /dev/urandom | tr -d ' \n' >"$KEY_FILE"
  fi
  chmod 600 "$KEY_FILE"
}

SRC=""
if ! SRC="$(find_src)"; then
  (prompt_txt 'src CLI not found, installing from the official installer...' &&
    tmp="$(mktemp -d)" &&
    curl -fsSL --connect-timeout 10 "$INSTALLER_URL" -o "$tmp/install.sh" &&
    sh "$tmp/install.sh" -n &&
    rm -rf "$tmp" &&
    show_success 'src CLI installed') || {
    show_error 'Failed to install src CLI'
    exit 1
  }
  SRC="$(find_src)" || {
    show_error 'src CLI not found after install'
    exit 1
  }
else
  show_success "Found src CLI: $SRC"
fi

if timeout "${SC_AUTH_TIMEOUT:-15}" "$SRC" auth status </dev/null >/dev/null 2>&1; then
  show_success 'SourceCraft auth OK'
else
  show_warn "Not authenticated: run 'src auth login', then re-run this script\n"
  show_warn "The script continues without auth — the proxy will return 401 until you log in\n"
  show_warn "WSL2: copy the login URL into a Windows browser; without a keyring set\n"
  show_warn "'cred_storage: file' in ~/.config/sourcecraft/config.yaml BEFORE 'src auth login'\n"
fi

systemd_ok=0
if command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload >/dev/null 2>&1; then
  systemd_ok=1
fi

if [ "$systemd_ok" -eq 1 ]; then
  if [ ! -f "$KEY_FILE" ]; then
    generate_key
    show_success "Generated API key: $KEY_FILE"
  fi
  KEY="$(cat "$KEY_FILE")"
  mkdir -p "$UNIT_DIR"
  sed -e "s|@SRC_PATH@|$SRC|g" -e "s|@KEY@|$KEY|g" \
    "$DIR/sourcecraft-ipc.service.in" >"$UNIT_FILE"
  systemctl --user daemon-reload
  systemctl --user enable --quiet sourcecraft-ipc
  systemctl --user restart sourcecraft-ipc
  sleep 1
  code="$(curl -s -m 5 -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/chat/completions" \
    -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' -d '{}' || true)"
  if [ "$code" = "400" ]; then
    show_success "Proxy is running on http://127.0.0.1:$PORT (systemd: sourcecraft-ipc)"
  else
    show_warn "Proxy answered HTTP $code — check: journalctl --user -u sourcecraft-ipc\n"
  fi
else
  show_warn "systemd (user) is not available — start the proxy manually:\n"
  show_warn "  bash $DIR/sc-ipc start\n"
fi

prompt_txt 'Models for opencode: sourcecraft/{default,deepseek-v4-flash,glm-5.2,qwen3.6-35b} and sourcecraft-external/{glm-5.3,glm-5.3-flash}'
prompt_txt 'zsh: plugin "sourcecraft" is enabled by default in .zshrc (inert until src CLI is installed)'
