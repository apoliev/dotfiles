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
fi
