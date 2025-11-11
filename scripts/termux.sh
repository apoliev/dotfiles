#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source $DIR/../shell/prompt_utils.sh

(prompt_txt 'Update all...' && pkg upgrade
show_success "Success\n") || (show_error 'Error' && exit 1)

(prompt_txt 'Install programs...' &&
pkg install $(cat $DIR/../termux/libs.list) &&
stow -d $DIR/../termux/ -t $HOME . &&
show_success "Success\n") || (show_error 'Error' && exit 1)

# Templates for shell
prompt_txt "\nLoading shell configs..." && sh -c $DIR/../shell/install.sh

# Templates for zsh
prompt_txt "\nLoading zsh configs..." && sh -c $DIR/../zsh/install.sh

# Templates for vim
prompt_txt "\nLoading vim configs..." && sh -c $DIR/../vim/install.sh

# Templates for tmux
prompt_txt "\nLoading tmux configs..." && sh -c $DIR/../tmux/install.sh
