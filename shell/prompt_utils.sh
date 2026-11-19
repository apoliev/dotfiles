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

backup_once() {
  local target="$1"
  local backup="${target}.bak"

  if [ ! -e "$target" ] || [ -L "$target" ]; then
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
