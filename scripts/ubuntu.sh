#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$DIR/.."

source "$REPO_ROOT/shell/prompt_utils.sh"

# ---- Steps ---------------------------------------------------------------

update_system() {
  prompt_txt 'Update all...'
  sudo apt update -y || { show_error 'apt update failed'; return 1; }
  sudo apt upgrade -y || { show_error 'apt upgrade failed'; return 1; }
  sudo apt autoremove -y || { show_error 'apt autoremove failed'; return 1; }

  if command -v snap >/dev/null 2>&1; then
    sudo snap refresh || { show_error 'snap refresh failed'; return 1; }
  else
    show_warn 'snap is not available, skipping snap refresh\n'
  fi

  show_success "Success\n"
}

install_system_packages() {
  prompt_txt 'Install programs...'
  sudo apt install -y $(cat "$REPO_ROOT/libs.list") ||
    { show_error 'Failed to install packages'; return 1; }
  show_success "Success\n"
}

install_mise() {
  local bin_dir="$HOME/.local/bin"
  local tmp_script="$HOME/.local/lib/mise-install.sh"

  mkdir -p "$bin_dir" "$HOME/.local/lib"

  prompt_txt 'Fetching latest mise release...'
  local api
  api="$(curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest)" ||
    { show_error 'Failed to query mise latest release'; return 1; }

  local version expected
  version="$(printf '%s' "$api" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  # Digest of the install.sh asset within the release payload.
  expected="$(printf '%s' "$api" | grep -A40 '"name": "install.sh"' | grep '"digest"' |
              head -n1 | sed -E 's/.*sha256:([0-9a-f]{64}).*/\1/')"

  prompt_txt "Downloading mise installer (${version})..."
  curl -fsSL -o "$tmp_script" \
    "https://github.com/jdx/mise/releases/download/${version}/install.sh" ||
    { show_error 'Failed to download mise installer'; return 1; }

  if [ -n "$expected" ]; then
    prompt_txt 'Verifying mise installer checksum...'
    echo "${expected}  ${tmp_script}" | sha256sum -c - >/dev/null ||
      { show_error 'mise installer checksum mismatch — aborting'; return 1; }
  else
    show_warn 'Could not determine official checksum — skipping verification\n'
  fi

  prompt_txt "Installing mise ${version}..."
  MISE_VERSION="$version" bash "$tmp_script" ||
    { show_error 'Failed to install mise'; return 1; }

  prompt_txt 'Installing mise tools...'
  "$bin_dir/mise" install ||
    { show_error 'Failed to install mise tools'; return 1; }

  show_success "Success\n"
}

stow_home() {
  prompt_txt 'Stowing dotfiles...'

  backup_once "$HOME/.zshrc"
  backup_once "$HOME/.tmux.conf"
  backup_once "$HOME/.vimrc"
  backup_once "$HOME/.irbrc"

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
install_mise

run_template shell "$REPO_ROOT/shell/install.sh"
run_template zsh "$REPO_ROOT/zsh/install.sh"
run_template vim "$REPO_ROOT/vim/install.sh"
run_template tmux "$REPO_ROOT/tmux/install.sh"
