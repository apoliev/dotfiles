#!/bin/bash

show_error() {
  echo -e "\033[91;1m✘ $1\033[0m"
}

show_success() {
  echo -e "\033[92;1m✔ $1\033[0m"
}

show_warn() {
  echo -e "⚠️$1"
}

prompt_txt() {
  echo -e "\e[33m$1\e[0m"
}

# Repo root, derived from this file's real location (readlink -f resolves
# the ~/.local/lib symlink installed by shell/install.sh).
DOTFILES_ROOT="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"

# True when $1 is a symlink that stow considers its own: the link destination
# is relative (stow never creates or accepts absolute links) and points into
# the repo with the same lexical prefix stow computes from the link's dir.
stow_owned_link() {
  local target="$1"
  local dest rel_root prefix
  dest="$(readlink "$target")" || return 1

  case "$dest" in
    /*) return 1 ;;  # absolute links are never owned by stow
  esac

  rel_root="$(realpath --relative-to="$(dirname "$target")" "$DOTFILES_ROOT")" || return 1
  prefix="${dest#"$rel_root"/}"
  [ "$prefix" != "$dest" ]
}

backup_once() {
  local target="$1"
  local backup="${target}.bak"

  if [ -L "$target" ]; then
    # Stow-owned links are kept (stow repairs its own broken ones). Foreign
    # ones — absolute links left by installers, links into a moved repo —
    # would make stow fail with "existing target is not owned by stow", so
    # they are backed up like regular files.
    stow_owned_link "$target" && return 0
  elif [ ! -e "$target" ]; then
    return 0
  fi

  if [ -e "$backup" ]; then
    show_warn "'$target' и '$backup' уже существуют\n"
    return 1
  fi

  mv "$target" "$backup"
  show_warn "Существующий файл '$target' сохранён как '$backup'\n"
  return 0
}

# require_cmds git:git curl:curl — check commands exist before the script
# starts working; on the first missing one, print an install hint using the
# package manager of the current system and return 1. Format: command:package.
require_cmds() {
  local -a missing=()
  local entry cmd pkg
  for entry in "$@"; do
    cmd="${entry%%:*}"
    pkg="${entry#*:}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  [ "${#missing[@]}" -eq 0 ] && return 0

  if command -v apt-get >/dev/null 2>&1; then
    show_error "Missing commands — install them and re-run: sudo apt install -y ${missing[*]}"
  elif command -v pkg >/dev/null 2>&1; then
    show_error "Missing commands — install them and re-run: pkg install ${missing[*]}"
  else
    show_error "Missing commands: ${missing[*]}"
  fi
  return 1
}
