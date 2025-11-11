#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source $DIR/../shell/prompt_utils.sh

oh_my_zsh_dir="$HOME/.oh-my-zsh"
if [ -d $oh_my_zsh_dir ]; then
  show_warn "Directory already exists\n"
else
  (prompt_txt 'Install Oh my zsh' &&
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &&
  show_success "Success\n") || (show_error 'Error' && exit 1)
fi

# load vendor plugins
fzf_tab_dir="$HOME/.oh-my-zsh/custom/plugins/fzf-tab"
if [ -d $fzf_tab_dir ]; then
  (prompt_txt 'Pulling updates for fzf-tab...' &&
  git -C $fzf_tab_dir pull &&
  show_success "Success\n") || (show_error 'Error' && exit 1)
else
  (prompt_txt 'Load fzf-tab...' &&
  git clone https://github.com/Aloxaf/fzf-tab $fzf_tab_dir &&
  show_success "Success\n") || (show_error 'Error' && exit 1)
fi

# Copying themes
(prompt_txt 'Copying themes...' &&
cp -R $DIR/themes/* $HOME/.oh-my-zsh/custom/themes &&
show_success "Success\n") || (show_error 'Error' && exit 1)
