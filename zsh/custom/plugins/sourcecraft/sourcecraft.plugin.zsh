# sourcecraft — SourceCraft CLI (src) + opencode models hookup.
#
# Inert unless the src CLI is installed (~/sourcecraft/bin/src or in PATH):
#   - adds the src CLI to PATH
#   - loads src shell completion
#   - exports SOURCECRAFT_IPC_API_KEY for the opencode SourceCraft providers
#     (set up with sourcecraft/install.sh, see sourcecraft/README.md)

if [ -x "$HOME/sourcecraft/bin/src" ] || command -v src >/dev/null 2>&1; then
  if [ -f "$HOME/sourcecraft/path.zsh.inc" ]; then
    source "$HOME/sourcecraft/path.zsh.inc"
  fi

  if [ -f "$HOME/sourcecraft/completion.zsh.inc" ]; then
    source "$HOME/sourcecraft/completion.zsh.inc"
  fi

  if [ -f "$HOME/.config/sourcecraft-ipc/key" ]; then
    export SOURCECRAFT_IPC_API_KEY="$(<"$HOME/.config/sourcecraft-ipc/key")"
  fi

  # regenerate the opencode SourceCraft providers when src refreshed its
  # model catalog (sourcecraft/update-models, merge-safe, cheap when fresh)
  _sc_cfg="$HOME/.config/opencode/opencode.jsonc"
  if [ ! -f "$_sc_cfg" ] ||
    [ -n "$(find "$HOME/.cache/sourcecraft" -name 'models-v3-*.json' -newer "$_sc_cfg" 2>/dev/null)" ]; then
    [ -x "$HOME/.dotfiles/sourcecraft/update-models" ] &&
      "$HOME/.dotfiles/sourcecraft/update-models" >/dev/null 2>&1
  fi
  unset _sc_cfg
fi
