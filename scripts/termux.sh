#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"
TERMUX_ROOT="$DIR/../termux"
REPO_ROOT="$DIR/.."

source "$REPO_ROOT/shell/prompt_utils.sh"

ALL_STEPS=(update packages chsh stow shell zsh vim tmux)

# ---- Steps ---------------------------------------------------------------

update_system() {
  prompt_txt 'Update all...'
  pkg upgrade ||
    { show_error 'pkg upgrade failed'; return 1; }
  show_success "Success\n"
}

install_system_packages() {
  prompt_txt 'Install programs...'
  # Unquoted on purpose: the package list is intentionally word-split.
  # shellcheck disable=SC2046
  pkg install $(cat "$TERMUX_ROOT/libs.list") ||
    { show_error 'Failed to install packages'; return 1; }
  show_success "Success\n"
}

set_default_shell() {
  command -v chsh >/dev/null 2>&1 || { show_error 'chsh not available'; return 1; }
  if [ "$(basename "${SHELL:-}")" = "zsh" ]; then
    show_warn "Default shell is already zsh\n"
  else
    prompt_txt 'Setting zsh as default shell...'
    chsh -s zsh || { show_error 'Failed to set default shell'; return 1; }
    show_success "Success — restart the Termux session to apply\n"
  fi
}

stow_home() {
  require_cmds stow:stow || return 1

  prompt_txt 'Stowing dotfiles...'

  backup_once "$HOME/.zshrc"
  backup_once "$HOME/.tmux.conf"
  backup_once "$HOME/.vimrc"
  backup_once "$HOME/.config/opencode/cli.json"

  # ~/.config must exist before stow runs — otherwise stow symlinks the whole
  # directory into the repo and programs write their configs into it
  mkdir -p "$HOME/.config"

  stow -d "$REPO_ROOT" -t "$HOME" . ||
    { show_error 'stow failed — resolve the conflicts listed above'; return 1; }

  show_success "Success\n"
}

# ---- Dispatcher ----------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: bash scripts/termux.sh [STEP...]

Run the whole Termux setup when called without arguments, or only the
selected steps.

Steps:
  update    pkg upgrade
  packages  install packages from termux/libs.list
  chsh      set zsh as the default shell
  stow      stow dotfiles into $HOME
  shell     link prompt_utils into ~/.local/lib
  zsh       oh-my-zsh + plugins + theme
  vim       vim-plug + theme + plugins
  tmux      TPM + plugins
  all       everything, in the default order
  help      show this help
EOF
}

run_step() {
  case "$1" in
    update)   update_system ;;
    packages) install_system_packages ;;
    chsh)     set_default_shell ;;
    stow)     stow_home ;;
    shell)    bash "$REPO_ROOT/shell/install.sh" ;;
    zsh)      bash "$REPO_ROOT/zsh/install.sh" ;;
    vim)      bash "$REPO_ROOT/vim/install.sh" ;;
    tmux)     bash "$REPO_ROOT/tmux/install.sh" ;;
  esac
}

# ---- Main ----------------------------------------------------------------

steps=()

if [ $# -eq 0 ]; then
  steps=("${ALL_STEPS[@]}")
else
  for arg in "$@"; do
    case "$arg" in
      all) steps=("${ALL_STEPS[@]}") ;;
      help|-h|--help) usage; exit 0 ;;
      update|packages|chsh|stow|shell|zsh|vim|tmux) steps+=("$arg") ;;
      *) show_error "Unknown step: $arg"; usage; exit 1 ;;
    esac
  done
fi

failed=()

for step in "${steps[@]}"; do
  if run_step "$step"; then
    :
  else
    failed+=("$step")
  fi
done

echo
if [ "${#failed[@]}" -gt 0 ]; then
  show_error "Failed steps: ${failed[*]}"
fi
[ "${#failed[@]}" -eq 0 ]
