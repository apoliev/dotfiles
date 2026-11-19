#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$DIR/.."

source "$REPO_ROOT/shell/prompt_utils.sh"

ALL_STEPS=(update packages chsh stow mise shell zsh vim tmux)

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
  # Unquoted on purpose: the package list is intentionally word-split.
  # shellcheck disable=SC2046
  sudo apt install -y $(cat "$REPO_ROOT/libs.list") ||
    { show_error 'Failed to install packages'; return 1; }
  show_success "Success\n"
}

install_mise() {
  command -v curl >/dev/null 2>&1 ||
    { show_error 'curl is required to download mise'; return 1; }

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

  prompt_txt 'Updating mise tools...'
  "$bin_dir/mise" up ||
    { show_error 'Failed to update mise tools'; return 1; }

  show_success "Success\n"
}

set_default_shell() {
  local zsh_path current_shell
  zsh_path="$(command -v zsh)" || { show_error 'zsh not found'; return 1; }
  current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [ "$current_shell" = "$zsh_path" ]; then
    show_warn "Default shell is already zsh\n"
  else
    prompt_txt 'Setting zsh as default shell...'
    sudo chsh -s "$zsh_path" "$(id -un)" ||
      { show_error 'Failed to set default shell'; return 1; }
    show_success "Success — re-login to apply\n"
  fi
}

stow_home() {
  require_cmds stow:stow || return 1

  prompt_txt 'Stowing dotfiles...'

  backup_once "$HOME/.zshrc"
  backup_once "$HOME/.tmux.conf"
  backup_once "$HOME/.vimrc"
  backup_once "$HOME/.irbrc"
  backup_once "$HOME/.config/opencode/cli.json"

  # ~/.config must exist before stow runs — otherwise stow symlinks the whole
  # directory into the repo and programs write their configs into it
  mkdir -p "$HOME/.config"

  # ~/.config/mise/config.toml is still stowed; mise creates it on first run
  mkdir -p "$HOME/.config/mise"

  stow -d "$REPO_ROOT" -t "$HOME" . ||
    { show_error 'stow failed — resolve the conflicts listed above'; return 1; }

  show_success "Success\n"
}

# ---- Dispatcher ----------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: bash scripts/ubuntu.sh [STEP...]

Run the whole Ubuntu setup when called without arguments, or only the
selected steps — handy on machines where some steps are not allowed.

Steps:
  update    apt update/upgrade/autoremove + snap refresh (needs sudo)
  packages  install packages from libs.list               (needs sudo)
  chsh      set zsh as the default shell                 (needs sudo)
  stow      stow dotfiles into $HOME
  mise      install mise + install/update tools from .config/mise
  shell     link prompt_utils into ~/.local/lib
  zsh       oh-my-zsh + plugins + theme
  vim       vim-plug + theme + plugins
  tmux      TPM + plugins
  all       everything, in the default order
  help      show this help
EOF
}

have_sudo() {
  command -v sudo >/dev/null 2>&1 || return 1
  # Already validated in this run — sudo caches credentials for a while
  [ "${SUDO_VALIDATED:-}" = "yes" ] && return 0
  # Prompts for the password when needed; fails for users without sudo rights
  if sudo -v; then SUDO_VALIDATED=yes; return 0; fi
  return 1
}

run_step() {
  case "$1" in
    update)   update_system ;;
    packages) install_system_packages ;;
    chsh)     set_default_shell ;;
    stow)     stow_home ;;
    mise)     install_mise ;;
    shell)    bash "$REPO_ROOT/shell/install.sh" ;;
    zsh)      bash "$REPO_ROOT/zsh/install.sh" ;;
    vim)      bash "$REPO_ROOT/vim/install.sh" ;;
    tmux)     bash "$REPO_ROOT/tmux/install.sh" ;;
  esac
}

# ---- Main ----------------------------------------------------------------

explicit=0
steps=()

if [ $# -eq 0 ]; then
  steps=("${ALL_STEPS[@]}")
else
  explicit=1
  for arg in "$@"; do
    case "$arg" in
      all) steps=("${ALL_STEPS[@]}") ;;
      help|-h|--help) usage; exit 0 ;;
      update|packages|chsh|stow|mise|shell|zsh|vim|tmux) steps+=("$arg") ;;
      *) show_error "Unknown step: $arg"; usage; exit 1 ;;
    esac
  done
fi

failed=()
skipped=()

for step in "${steps[@]}"; do
  # Sudo-only steps degrade to a skip when the user has no admin rights
  case "$step" in
    update|packages|chsh)
      if ! have_sudo; then
        if [ "$explicit" -eq 1 ]; then
          show_error "Step '$step' needs admin rights (sudo)"
          failed+=("$step")
        else
          show_warn "No admin rights — step '$step' skipped\n"
          skipped+=("$step")
        fi
        continue
      fi
      ;;
  esac

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
if [ "${#skipped[@]}" -gt 0 ]; then
  show_warn "Skipped steps (no admin rights): ${skipped[*]}\n"
fi
[ "${#failed[@]}" -eq 0 ]
