#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source "$DIR/../shell/prompt_utils.sh"

# Loading vim-plug (idempotent)
plug_file="$HOME/.vim/autoload/plug.vim"
prompt_txt 'Loading vim-plug...'
if [ -f "$plug_file" ]; then
  show_warn "Already installed\n"
else
  (mkdir -p "$HOME/.vim/autoload" &&
   curl -fsSL -o "$plug_file" \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim &&
   show_success "Success\n") || (show_error 'Error' && exit 1)
fi

# Loading theme (native pack, updated in place when it is a git checkout)
theme_dir="$HOME/.vim/pack/josuegaleas/start/jay"
prompt_txt 'Loading theme...'
if [ -d "$theme_dir/.git" ]; then
  (git -C "$theme_dir" pull --ff-only &&
   show_success "Success\n") || (show_error 'Error' && exit 1)
elif [ -d "$theme_dir" ]; then
  show_warn "Theme directory exists but is not a git checkout — leaving as-is\n"
else
  (git clone --depth=1 https://github.com/josuegaleas/jay.git "$theme_dir" &&
   show_success "Success\n") || (show_error 'Error' && exit 1)
fi

# Installing / updating plugins via vim-plug
prompt_txt 'Install Plugins...'
if vim +PlugInstall +qall; then
  show_success "Success\n"
else
  show_error 'Error'
  exit 1
fi
