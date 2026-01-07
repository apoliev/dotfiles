#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source $DIR/../shell/prompt_utils.sh

(prompt_txt 'Update all...' &&
sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y &&
sudo snap refresh &&
show_success "Success\n") || (show_error 'Error' && exit 1)

(prompt_txt 'Install programs...' &&
sudo apt install -y $(cat $DIR/../libs.list) &&
curl https://mise.jdx.dev/install.sh | sh &&
mv $HOME/.zshrc $HOME/.zshrc.bak &&
mv $HOME/.tmux.conf $HOME/.tmux.conf.bak &&
mv $HOME/.vimrc $HOME/.vimrc.bak &&
mv $HOME/.irbrc $HOME/.irbrc.bak &&
stow -d $DIR/../ -t $HOME . &&
sh -c "$HOME/.local/bin/mise install" &&
show_success "Success\n") || (show_error 'Error' && exit 1)

# Templates for shell
prompt_txt "\nLoading shell configs..." && sh -c $DIR/../shell/install.sh

# Templates for zsh
prompt_txt "\nLoading zsh configs..." && sh -c $DIR/../zsh/install.sh

# Templates for vim
prompt_txt "\nLoading vim configs..." && sh -c $DIR/../vim/install.sh

# Templates for tmux
prompt_txt "\nLoading tmux configs..." && sh -c $DIR/../tmux/install.sh
