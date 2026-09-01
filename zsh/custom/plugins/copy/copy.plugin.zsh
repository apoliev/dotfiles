# copy — cross-platform clipboard helper (oh-my-zsh custom plugin).
#
# Provides a `copy` command that sends stdin or a selection to the system
# clipboard using whatever tool is available on the current platform:
#   Termux    -> termux-clipboard-set
#   X11       -> xclip
#   Wayland   -> wl-copy
#   macOS     -> pbcopy

copy() {
  if [ -n "$TERMUX_VERSION" ]; then
    termux-clipboard-set
  elif command -v xclip >/dev/null 2>&1; then
    xclip -i -sel c
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  else
    echo "copy: no supported clipboard tool found" >&2
    return 1
  fi
}
