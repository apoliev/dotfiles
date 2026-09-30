#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(dirname "$DIR")"

# shellcheck disable=SC1091
source "$REPO_ROOT/shell/prompt_utils.sh"

# ---- Steps ---------------------------------------------------------------

trust_repo() {
  git config --global --add safe.directory "$REPO_ROOT"
}

set_git_identity() {
  if [ -z "$(git config --global user.name)" ]; then
    git config --global user.name "${GIT_AUTHOR_NAME:-$(id -un)}"
  fi
  if [ -z "$(git config --global user.email)" ]; then
    git config --global user.email "${GIT_AUTHOR_EMAIL:-$(id -un)@localhost}"
  fi
}

stow_home() {
  prompt_txt 'Stowing dotfiles into the sandbox home...'
  mkdir -p "$HOME/.config"

  stow -d "$REPO_ROOT" -t "$HOME" . ||
    { show_error 'stow failed — resolve the conflicts listed above'; return 1; }

  show_success "Success\n"
}

check_harness() {
  prompt_txt 'Checking opencode...'
  mise reshim

  if ! command -v opencode >/dev/null 2>&1; then
    show_error 'opencode not found — check mise install in the image'
    return 1
  fi
  opencode --version

  show_success "Success\n"
}

# ---- Main ----------------------------------------------------------------

trust_repo
set_git_identity
stow_home
check_harness
