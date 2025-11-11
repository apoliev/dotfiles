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
