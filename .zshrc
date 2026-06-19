export GPG_TTY=$(tty)
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export ZOXIDE_CMD_OVERRIDE=cd
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="bira-shell"

plugins=(
  git
  mise
  fzf-tab
  qrcode
  zoxide
)

setopt interactivecomments

alias copy='xclip -i -sel c'

source $ZSH/oh-my-zsh.sh
