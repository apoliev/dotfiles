export GPG_TTY=$(tty)
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

if [ -d "$HOME/.local/share/mise/shims" ]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

export ZOXIDE_CMD_OVERRIDE=cd
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="bira-shell"

plugins=(
  copy
  fzf
  fzf-tab
  git
  qrcode
)

if command -v zoxide >/dev/null 2>&1; then
  plugins+=(zoxide)
fi

# mise is not available on Termux
if [ -z "$TERMUX_VERSION" ] && command -v mise >/dev/null 2>&1; then
  plugins+=(mise)
fi

setopt interactivecomments

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

source $ZSH/oh-my-zsh.sh
