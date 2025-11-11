#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source $DIR/../shell/prompt_utils.sh

# Loading Vundle
vundle_directory="$HOME/.vim/bundle/Vundle.vim"
prompt_txt 'Loading Vundle...'
if [ -d $vundle_directory ]; then
  show_warn "Directory already exists\n"
else
  (git clone https://github.com/VundleVim/Vundle.vim.git $vundle_directory && show_success "Success\n") || (show_error 'Error' && exit 1)
fi

# Loading theme
theme_directory="$HOME/.vim/pack/josuegaleas/start/jay"
prompt_txt 'Loading theme...'
if [ -d $theme_directory ]; then
  show_warn "Directory already exists\n"
else
  (git clone --depth=1 https://github.com/josuegaleas/jay.git $HOME/.vim/pack/josuegaleas/start/jay && show_success "Success\n") || (show_error 'Error' && exit 1)
fi

# Instaliing plugins
(prompt_txt 'Install Plugins...' &&
vim +PluginInstall +qall &&
show_success "Success\n") || (show_error 'Error' && exit 1)
