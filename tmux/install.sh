#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

# shellcheck disable=SC1091
source "$DIR/../shell/prompt_utils.sh"

# Loading plugins
tmux_plugin_dir="$HOME/.tmux/plugins/tpm"
prompt_txt 'Loading plugins...'
if [ -d "$tmux_plugin_dir" ]; then
  show_warn "Directory already exists\n"
else
  (git clone https://github.com/tmux-plugins/tpm "$tmux_plugin_dir" &&
  show_success "Success\n") || (show_error 'Error' || exit 1)
fi

(prompt_txt 'Install or update plugins...' &&
TMUX_HEADLESS=1 bash "$HOME/.tmux/plugins/tpm/bin/install_plugins" &&
TMUX_HEADLESS=1 bash "$HOME/.tmux/plugins/tpm/bin/update_plugins" all &&
show_success "Success\n") || (show_error 'Error' && exit 1)

# TPM helper scripts spawn a headless server (`tmux start-server`); it normally
# exits by itself, but kill it if it lingers - only when there are no sessions.
if ! tmux list-sessions >/dev/null 2>&1; then
  tmux kill-server >/dev/null 2>&1 || true
fi
