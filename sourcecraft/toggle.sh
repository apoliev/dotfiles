#!/bin/bash
# Toggle SourceCraft integration on/off:
#   enable   — link the zsh plugin, add it to plugins=(...) in .zshrc and run
#              install.sh (src CLI, sourcecraft-ipc unit, opencode providers)
#   disable  — the inverse: remove the systemd unit, strip the SourceCraft
#              providers from the opencode config, unlink the plugin and drop
#              it from .zshrc. --purge also removes the ipc key dir and the
#              model catalog cache
#   status   — show what is currently on
# Safe to re-run in any state. Data (src CLI, auth, keys, cache) is kept
# unless --purge is given. See README.md.

set -e

DIR="$(dirname "$(readlink -f "$0")")"

# shellcheck disable=SC1091
source "$DIR/../shell/prompt_utils.sh"

ZSHRC="$HOME/.zshrc"
PLUGIN_SRC="$DIR/../zsh/custom/plugins/sourcecraft"
OMZ_PLUGIN="$HOME/.oh-my-zsh/custom/plugins/sourcecraft"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/sourcecraft-ipc.service"
UNIT_NAME="sourcecraft-ipc"
OC_CONFIG="$HOME/.config/opencode/opencode.jsonc"
PURGE=0

usage() {
  prompt_txt 'usage: toggle.sh enable | disable [--purge] | status'
}

# --- zsh plugin -------------------------------------------------------------

zshrc_has_plugin() {
  [ -f "$ZSHRC" ] && grep -Eq '^[[:space:]]+sourcecraft[[:space:]]*$' "$ZSHRC"
}

# Insert 'sourcecraft' before the closing paren of the plugins=( ... ) block.
# The result is streamed through the existing file (cat >) so a stow symlink
# pointing at the repo .zshrc stays a symlink.
zshrc_add_plugin() {
  zshrc_has_plugin && return 0
  if [ ! -f "$ZSHRC" ]; then
    show_warn "'$ZSHRC' not found — enable the plugin manually\n"
    return 0
  fi
  tmp="$(mktemp)"
  awk '/^plugins=\(/{inblock=1} /^\)$/ && inblock && !done {print "  sourcecraft"; done=1} {print}' \
    "$ZSHRC" >"$tmp"
  if ! grep -Eq '^[[:space:]]+sourcecraft[[:space:]]*$' "$tmp"; then
    rm -f "$tmp"
    show_warn "plugins=( block not found in '$ZSHRC' — add the plugin manually\n"
    return 0
  fi
  cat "$tmp" >"$ZSHRC"
  rm -f "$tmp"
  show_success "plugin enabled in $ZSHRC"
}

zshrc_remove_plugin() {
  zshrc_has_plugin || return 0
  tmp="$(mktemp)"
  grep -Ev '^[[:space:]]*sourcecraft[[:space:]]*$' "$ZSHRC" >"$tmp" || true
  cat "$tmp" >"$ZSHRC"
  rm -f "$tmp"
  show_success "plugin removed from $ZSHRC"
}

plugin_link() {
  if [ ! -d "$PLUGIN_SRC" ]; then
    show_error "plugin source not found: $PLUGIN_SRC"
    exit 1
  fi
  mkdir -p "$(dirname "$OMZ_PLUGIN")"
  rm -rf "$OMZ_PLUGIN"
  ln -s "$PLUGIN_SRC" "$OMZ_PLUGIN"
  show_success "linked $OMZ_PLUGIN"
}

plugin_unlink() {
  if [ -L "$OMZ_PLUGIN" ]; then
    rm -f "$OMZ_PLUGIN"
    show_success "unlinked $OMZ_PLUGIN"
  elif [ -e "$OMZ_PLUGIN" ]; then
    show_warn "'$OMZ_PLUGIN' is not our symlink — left untouched\n"
  fi
}

# --- systemd unit -----------------------------------------------------------

# The unit file under $HOME is the source of truth: without it there is
# nothing to do (also keeps the test suite from touching the real session).
unit_remove() {
  if [ ! -e "$UNIT_FILE" ] && [ ! -L "$UNIT_FILE" ]; then
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now "$UNIT_NAME" >/dev/null 2>&1 || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  rm -f "$UNIT_FILE"
  show_success "removed $UNIT_FILE"
}

# --- opencode config --------------------------------------------------------

# Strip the SourceCraft providers from the opencode config; everything else is
# kept. If nothing but $schema remains, the file is removed entirely. Mirrors
# update-models: parseable JSON only, atomic replace.
config_strip() {
  if ! command -v python3 >/dev/null 2>&1; then
    show_warn 'python3 not found — remove the sourcecraft providers from\n'
    show_warn "  $OC_CONFIG manually\n"
    return 0
  fi
  python3 - "$OC_CONFIG" <<'PY'
import json
import os
import sys
import tempfile

path = sys.argv[1]
providers = ("sourcecraft", "sourcecraft-external")
if not os.path.exists(path):
    sys.exit(0)
try:
    with open(path) as f:
        cfg = json.load(f)
except (OSError, ValueError) as e:
    print(f"skipping: {path} is not parseable JSON ({e})")
    sys.exit(0)

section = cfg.get("provider")
if not isinstance(section, dict) or not any(p in section for p in providers):
    sys.exit(0)

for p in providers:
    section.pop(p, None)
if not section:
    del cfg["provider"]

if not {k: v for k, v in cfg.items() if k != "$schema"}:
    os.remove(path)
    print(f"removed {path} (nothing but SourceCraft was left)")
    sys.exit(0)

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
with os.fdopen(fd, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
print(f"stripped SourceCraft providers from {path}")
PY
}

# --- status -----------------------------------------------------------------

config_has_providers() {
  [ -f "$OC_CONFIG" ] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$OC_CONFIG" <<'PY'
import json
import sys

try:
    with open(sys.argv[1]) as f:
        cfg = json.load(f)
except (OSError, ValueError):
    sys.exit(1)
p = cfg.get("provider")
ok = isinstance(p, dict) and ("sourcecraft" in p or "sourcecraft-external" in p)
sys.exit(0 if ok else 1)
PY
}

unit_state() {
  if [ ! -e "$UNIT_FILE" ]; then
    echo 'absent'
  elif command -v systemctl >/dev/null 2>&1; then
    systemctl --user is-active "$UNIT_NAME" 2>/dev/null || echo 'inactive/failed'
  else
    echo 'unit file present (systemd unavailable)'
  fi
}

status() {
  prompt_txt 'SourceCraft integration:'
  echo "  systemd unit : $(unit_state)"
  if config_has_providers; then
    echo "  opencode     : providers present in $OC_CONFIG"
  else
    echo "  opencode     : no providers in $OC_CONFIG"
  fi
  if [ -L "$OMZ_PLUGIN" ]; then
    echo "  zsh plugin   : linked ($(readlink "$OMZ_PLUGIN"))"
  else
    echo '  zsh plugin   : not linked'
  fi
  if zshrc_has_plugin; then
    echo '                 enabled in plugins=(...)'
  else
    echo '                 not in plugins=(...)'
  fi
}

# --- actions ----------------------------------------------------------------

do_enable() {
  plugin_link
  zshrc_add_plugin
  prompt_txt 'Running install.sh (src CLI, sourcecraft-ipc unit, opencode providers)...'
  if ! bash "$DIR/install.sh"; then
    show_error 'install.sh failed — fix the issue and re-run toggle.sh enable'
    exit 1
  fi
  show_success 'SourceCraft integration enabled'
}

do_disable() {
  unit_remove
  config_strip
  plugin_unlink
  zshrc_remove_plugin
  if [ "$PURGE" -eq 1 ]; then
    rm -rf "$HOME/.config/sourcecraft-ipc" "$HOME/.cache/sourcecraft"
    show_success 'purged ~/.config/sourcecraft-ipc and ~/.cache/sourcecraft'
  fi
  show_success 'SourceCraft integration disabled (re-enable: toggle.sh enable)'
}

case "${1:-}" in
  enable) do_enable ;;
  disable)
    if [ "${2:-}" = "--purge" ]; then
      PURGE=1
    elif [ -n "${2:-}" ]; then
      usage
      exit 1
    fi
    do_disable
    ;;
  status) status ;;
  *)
    usage
    exit 1
    ;;
esac
