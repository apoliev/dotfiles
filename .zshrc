export GPG_TTY=$(tty)
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export ZOXIDE_CMD_OVERRIDE=cd
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="bira-shell"
ZSH_TMUX_AUTOSTART=true

plugins=(
  git
  mise
  fzf-tab
  qrcode
  zoxide
  tmux
)

setopt interactivecomments

alias copy='xclip -i -sel c'

source $ZSH/oh-my-zsh.sh
