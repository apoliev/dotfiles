#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source "$DIR/../shell/prompt_utils.sh"

CUSTOM_DIR="$HOME/.oh-my-zsh/custom"

# Oh My Zsh (downloaded to a file, executed explicitly with bash)
oh_my_zsh_dir="$HOME/.oh-my-zsh"
if [ -d "$oh_my_zsh_dir" ]; then
  show_warn "Oh My Zsh already installed\n"
else
  tmp_installer="$HOME/.local/lib/oh-my-zsh-install.sh"
  mkdir -p "$HOME/.local/lib"

  prompt_txt 'Downloading Oh My Zsh installer...'
  curl -fsSL -o "$tmp_installer" \
    https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh ||
    { show_error 'Failed to download Oh My Zsh installer'; exit 1; }

  prompt_txt 'Installing Oh My Zsh...'
  RUNZSH=no CHSH=no bash "$tmp_installer" ||
    { show_error 'Failed to install Oh My Zsh'; exit 1; }
fi

# vendor plugin: fzf-tab (shallow clone, updated in place when possible)
fzf_tab_dir="$CUSTOM_DIR/plugins/fzf-tab"
prompt_txt 'Loading fzf-tab...'
if [ -d "$fzf_tab_dir/.git" ]; then
  git -C "$fzf_tab_dir" pull --ff-only ||
    { show_error 'Failed to update fzf-tab'; exit 1; }
elif [ -d "$fzf_tab_dir" ]; then
  show_warn "fzf-tab exists but is not a git checkout — leaving as-is\n"
else
  git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$fzf_tab_dir" ||
    { show_error 'Failed to clone fzf-tab'; exit 1; }
fi
show_success "Success\n"

# custom plugin: copy
prompt_txt 'Linking copy plugin...'
mkdir -p "$CUSTOM_DIR/plugins"
rm -rf "$CUSTOM_DIR/plugins/copy"
ln -s "$DIR/custom/plugins/copy" "$CUSTOM_DIR/plugins/copy" ||
  { show_error 'Failed to link copy plugin'; exit 1; }
show_success "Success\n"

# theme
prompt_txt 'Linking theme...'
rm -rf "$CUSTOM_DIR/themes/bira-shell.zsh-theme"
ln -s "$DIR/themes/bira-shell.zsh-theme" "$CUSTOM_DIR/themes/bira-shell.zsh-theme" ||
  { show_error 'Failed to link theme'; exit 1; }
show_success "Success\n"
