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
