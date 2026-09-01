#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"
TERMUX_ROOT="$DIR/../termux"
REPO_ROOT="$DIR/.."

source "$REPO_ROOT/shell/prompt_utils.sh"

# ---- Steps ---------------------------------------------------------------

update_system() {
  prompt_txt 'Update all...'
  pkg upgrade ||
    { show_error 'pkg upgrade failed'; return 1; }
  show_success "Success\n"
}

install_system_packages() {
  prompt_txt 'Install programs...'
  pkg install $(cat "$TERMUX_ROOT/libs.list") ||
    { show_error 'Failed to install packages'; return 1; }
  show_success "Success\n"
}

stow_home() {
  prompt_txt 'Stowing dotfiles...'

  backup_once "$HOME/.zshrc"
  backup_once "$HOME/.tmux.conf"
  backup_once "$HOME/.vimrc"

  stow -d "$REPO_ROOT" -t "$HOME" . ||
    { show_error 'stow failed — resolve the conflicts listed above'; return 1; }

  show_success "Success\n"
}

run_template() {
  local name="$1"
  local script="$2"
  prompt_txt "Loading ${name} configs..."
  bash "$script"
}

# ---- Main ----------------------------------------------------------------

update_system
install_system_packages
stow_home

run_template shell "$REPO_ROOT/shell/install.sh"
run_template zsh "$REPO_ROOT/zsh/install.sh"
run_template vim "$REPO_ROOT/vim/install.sh"
run_template tmux "$REPO_ROOT/tmux/install.sh"
