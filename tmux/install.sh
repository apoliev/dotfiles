#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source $DIR/../shell/prompt_utils.sh

# Loading plugins
tmux_plugin_dir="$HOME/.tmux/plugins/tpm"
prompt_txt 'Loading plugins...'
if [ -d $tmux_plugin_dir ]; then
  show_warn "Directory already exists\n"
else
  (git clone https://github.com/tmux-plugins/tpm $tmux_plugin_dir &&
  show_success "Success\n") || (show_error 'Error' || exit 1)
fi

(prompt_txt 'Install or update plugins...' &&
sh -c $HOME/.tmux/plugins/tpm/bin/install_plugins &&
sh -c "$HOME/.tmux/plugins/tpm/bin/update_plugins all"
show_success "Success\n") || (show_error 'Error' && exit 1)
